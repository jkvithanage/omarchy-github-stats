// In-memory service state. The QML adapter owns processes and the wall clock.
var refreshInterval = 15 * 60 * 1000;
var identityQuery = "query { viewer { id login } }";
var summaryFields = "totalCommitContributions totalPullRequestContributions totalIssueContributions restrictedContributionsCount ";
var calendarQuery = "query($login: String!, $from: DateTime!, $weekFrom: DateTime!, $monthFrom: DateTime!, $to: DateTime!) { "
    + "viewer { id login } user(login: $login) { id login "
    + "contributionsCollection(from: $from, to: $to) { " + summaryFields + "contributionCalendar { "
    + "weeks { contributionDays { date contributionCount contributionLevel } } } } "
    + "week: contributionsCollection(from: $weekFrom, to: $to) { " + summaryFields + "} "
    + "month: contributionsCollection(from: $monthFrom, to: $to) { " + summaryFields + "} } }";
var languageFields = "languages(first: 100, after: $languageCursor) { totalCount pageInfo { hasNextPage endCursor } edges { size node { name } } } ";
var repositoryQuery = "query($login: String!, $cursor: String, $languageCursor: String) { viewer { id login } user(login: $login) { id login "
    + "repositories(first: 100, after: $cursor, ownerAffiliations: [OWNER], isFork: false) { totalCount pageInfo { hasNextPage endCursor } "
    + "nodes { id owner { id login } isFork stargazerCount " + languageFields + "} } } }";
var languageQuery = "query($id: ID!, $languageCursor: String!) { viewer { id login } node(id: $id) { ... on Repository { "
    + "id owner { id login } isFork " + languageFields + "} } }";
// The overlap lookup supplies badges only, never totals or a third group.
// With the same ordering, an authored top-ten match is also in the subset's top ten.
function workQuery(kind) {
    var type = kind === "prs" ? "PullRequest" : "Issue";
    var fields = "... on " + type + " { id number title url updatedAt state " + (kind === "prs" ? "isDraft " : "")
        + "author { login } repository { nameWithOwner isPrivate } } ";
    return "query($authored: String!, $secondary: String!, $overlap: String!) { viewer { id login } "
        + "authored: search(query: $authored, type: ISSUE, first: 10) { issueCount nodes { __typename " + fields + "} } "
        + "secondary: search(query: $secondary, type: ISSUE, first: 10) { issueCount nodes { __typename " + fields + "} } "
        + "overlap: search(query: $overlap, type: ISSUE, first: 10) { nodes { ... on " + type + " { id } } } }";
}

function utcDate(now) { return new Date(now).toISOString().slice(0, 10); }

function annualStart(now) {
    var date = new Date(now);
    var year = date.getUTCFullYear() - 1;
    var month = date.getUTCMonth();
    var day = Math.min(date.getUTCDate(), new Date(Date.UTC(year, month + 1, 0)).getUTCDate());
    return new Date(Date.UTC(year, month, day + 1)).toISOString();
}

function periodStart(now, days) {
    return new Date(Date.parse(utcDate(now) + "T00:00:00Z") - (days - 1) * 86400000).toISOString();
}

function command(query, fields) {
    var args = ["gh", "api", "--hostname", "github.com", "--include", "graphql", "-f", "query=" + query];
    for (var key in fields) args.push("-f", key + "=" + fields[key]);
    return args;
}

function validIdentity(value) {
    return value && typeof value.id === "string" && value.id.length > 0
        && typeof value.login === "string" && /^[A-Za-z0-9-]+$/.test(value.login);
}

function sameIdentity(a, b) {
    return validIdentity(a) && validIdentity(b) && a.id === b.id && a.login === b.login;
}

function decode(result) {
    var text = String(result.stdout || "").replace(/\r\n/g, "\n");
    var headers = {};
    var status = 0;
    while (/^HTTP\/\S+ \d+/.test(text)) {
        var end = text.indexOf("\n\n");
        if (end < 0) break;
        var lines = text.slice(0, end).split("\n");
        status = Number(lines.shift().split(" ")[1]);
        lines.forEach(function(line) {
            var colon = line.indexOf(":");
            if (colon > 0) headers[line.slice(0, colon).toLowerCase()] = line.slice(colon + 1).trim();
        });
        text = text.slice(end + 2);
    }
    var body = null;
    try { body = JSON.parse(text); } catch (_) { /* Classified below; never log responses. */ }
    return { body: body, status: status, headers: headers };
}

function failureKind(result, decoded) {
    if (result.failure) return result.failure;
    var body = decoded.body;
    var message = String(result.stderr || "") + " " + (body ? JSON.stringify(body.errors || body.message || "") : "");
    if (decoded.status === 401 || /bad credentials|gh auth login|not logged|requires authentication|UNAUTHENTICATED/i.test(message)) return "authentication";
    if (decoded.status === 429 || /rate.?limit|RATE_LIMITED|abuse detection/i.test(message)
        || decoded.headers["x-ratelimit-remaining"] === "0" && decoded.status === 403) return "rate-limit";
    if (decoded.status === 403 || decoded.status === 404 || /FORBIDDEN|INSUFFICIENT_SCOPES|resource not accessible|permission|requires.*scope/i.test(message)) return "permission";
    if (decoded.status >= 500 || /connecting to|dial tcp|no such host|network|connection|TLS|certificate|timed out|unexpected EOF/i.test(message)) return "network";
    if (result.code !== 0) return "gh";
    if (!body || body.errors || !body.data) return "response";
    return "";
}

function retryTime(decoded, now) {
    var guidance = [];
    var retry = decoded.headers["retry-after"];
    if (retry) guidance.push(/^\d+$/.test(retry) ? now + Number(retry) * 1000 : Date.parse(retry));
    var reset = Number(decoded.headers["x-ratelimit-reset"]);
    if (isFinite(reset) && reset > 0) guidance.push(reset * 1000);
    var rate = decoded.body && decoded.body.data && decoded.body.data.rateLimit;
    if (rate) guidance.push(Date.parse(rate.resetAt));
    var valid = guidance.filter(function(time) { return isFinite(time) && time > now; });
    return valid.length ? Math.max.apply(Math, valid) : now + refreshInterval;
}

function calendarDays(user) {
    var calendar = user && user.contributionsCollection && user.contributionsCollection.contributionCalendar;
    if (!calendar || !Array.isArray(calendar.weeks)) return null;
    var days = {};
    var levels = ["NONE", "FIRST_QUARTILE", "SECOND_QUARTILE", "THIRD_QUARTILE", "FOURTH_QUARTILE"];
    for (var w = 0; w < calendar.weeks.length; w++) {
        var week = calendar.weeks[w];
        if (!week || !Array.isArray(week.contributionDays)) return null;
        for (var d = 0; d < week.contributionDays.length; d++) {
            var day = week.contributionDays[d];
            if (!day || typeof day.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(day.date)) return null;
            var parsed = Date.parse(day.date + "T00:00:00Z");
            if (!isFinite(parsed) || utcDate(parsed) !== day.date || days[day.date]) return null;
            if (typeof day.contributionCount !== "number" || !isFinite(day.contributionCount)
                || day.contributionCount < 0 || Math.floor(day.contributionCount) !== day.contributionCount
                || levels.indexOf(day.contributionLevel) < 0) return null;
            days[day.date] = { date: day.date, contributionCount: day.contributionCount, contributionLevel: day.contributionLevel };
        }
    }
    return days;
}

function validCount(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 && Math.floor(value) === value;
}

function periodStats(calendar, collection, from, to) {
    if (!collection || !validCount(collection.totalCommitContributions)
        || !validCount(collection.totalPullRequestContributions) || !validCount(collection.totalIssueContributions)
        || !validCount(collection.restrictedContributionsCount)) return null;
    var days = [];
    var total = 0;
    for (var date = Date.parse(from); date <= Date.parse(to); date += 86400000) {
        var day = calendar[utcDate(date)];
        if (!day) return null;
        days.push(day);
        total += day.contributionCount;
    }
    return { from: from, to: to, days: days, contributions: total,
        commitContributions: collection.totalCommitContributions,
        prsAuthored: collection.totalPullRequestContributions, issuesAuthored: collection.totalIssueContributions,
        restrictedContributions: collection.restrictedContributionsCount };
}

function accountStats(calendar, user, at) {
    var to = new Date(at).toISOString();
    var periods = {
        week: periodStats(calendar, user.week, periodStart(at, 7), to),
        month: periodStats(calendar, user.month, periodStart(at, 30), to),
        year: periodStats(calendar, user.contributionsCollection, annualStart(at), to)
    };
    if (!periods.week || !periods.month || !periods.year) return null;
    for (var key in periods) periods[key].layout = calendarLayout(periods[key].days, key);
    return { at: at, periods: periods };
}

function calendarLayout(days, period) {
    if (period === "week") return { columns: 7, rows: 1, cells: days, months: [] };
    var offset = new Date(days[0].date + "T00:00:00Z").getUTCDay();
    var cells = [];
    for (var i = 0; i < offset; i++) cells.push(null);
    cells = cells.concat(days);
    while (cells.length % 7) cells.push(null);
    var months = [];
    if (period === "year") {
        days.forEach(function(day, index) {
            if (index !== 0 && day.date.slice(8) !== "01") return;
            var column = Math.floor((offset + index) / 7);
            // Omit a tiny initial partial month when its label would collide.
            if (months.length && column - months[months.length - 1].column < 3) months.pop();
            months.push({ date: day.date.slice(0, 7), column: column });
        });
    }
    return { columns: period === "year" ? cells.length / 7 : 7,
        rows: period === "year" ? 7 : cells.length / 7, cells: cells, months: months };
}

function pageState() { return { total: null, count: 0, cursor: "", more: true, cursors: Object.create(null) }; }

function readPage(connection, items, state) {
    if (!connection || !Array.isArray(items) || !validCount(connection.totalCount) || !connection.pageInfo
        || typeof connection.pageInfo.hasNextPage !== "boolean") return false;
    if (state.total !== null && state.total !== connection.totalCount) return false;
    state.total = connection.totalCount;
    state.count += items.length;
    state.more = connection.pageInfo.hasNextPage;
    if (state.more) {
        var cursor = connection.pageInfo.endCursor;
        if (!items.length || state.count >= state.total || typeof cursor !== "string" || !cursor || state.cursors[cursor]) return false;
        state.cursors[cursor] = true;
        state.cursor = cursor;
    }
    return state.more ? state.count < state.total : state.count === state.total;
}

function RepositoryScan(identity) {
    this.identity = identity;
    this.page = pageState();
    this.seen = Object.create(null);
    this.pendingLanguages = [];
    this.bytes = Object.create(null);
    this.stars = 0;
    this.repositoryCount = 0;
}

RepositoryScan.prototype.languages = function(connection, repository) {
    if (!readPage(connection, connection && connection.edges, repository.page)) return false;
    for (var i = 0; i < connection.edges.length; i++) {
        var edge = connection.edges[i];
        var name = edge && edge.node && edge.node.name;
        if (typeof name !== "string" || !name || repository.seen[name] || !validCount(edge.size)) return false;
        repository.seen[name] = true;
        this.bytes[name] = (this.bytes[name] || 0) + edge.size;
    }
    return true;
};

RepositoryScan.prototype.repositories = function(connection) {
    if (!readPage(connection, connection && connection.nodes, this.page)) return false;
    for (var i = 0; i < connection.nodes.length; i++) {
        var node = connection.nodes[i];
        if (!node || typeof node.id !== "string" || !node.id || this.seen[node.id]
            || !validIdentity(node.owner) || typeof node.isFork !== "boolean") return false;
        this.seen[node.id] = true;
        if (node.isFork || !sameIdentity(this.identity, node.owner)) continue;
        if (!validCount(node.stargazerCount)) return false;
        this.stars += node.stargazerCount;
        this.repositoryCount++;
        var repository = { id: node.id, page: pageState(), seen: Object.create(null) };
        if (!this.languages(node.languages, repository)) return false;
        if (repository.page.more) this.pendingLanguages.push(repository);
    }
    return true;
};

RepositoryScan.prototype.next = function() {
    if (this.page.more) return { kind: "repositories", cursor: this.page.cursor };
    var repository = this.pendingLanguages[0];
    return repository ? { kind: "languages", id: repository.id, cursor: repository.page.cursor } : null;
};

RepositoryScan.prototype.snapshot = function() {
    var bytes = this.bytes;
    var languages = Object.keys(bytes).map(function(name) { return { name: name, bytes: bytes[name] }; });
    languages.sort(function(a, b) { return b.bytes - a.bytes || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0); });
    var total = languages.reduce(function(sum, language) { return sum + language.bytes; }, 0);
    var top = languages.slice(0, 5);
    var other = languages.slice(5).reduce(function(sum, language) { return sum + language.bytes; }, 0);
    if (other > 0) top.push({ name: "Other", bytes: other });
    top.forEach(function(language) { language.percentage = total ? language.bytes / total * 100 : 0; });
    return { stars: this.stars, repositoryCount: this.repositoryCount, totalBytes: total, languages: total ? top : [] };
};

function sectionState() { return { data: null, lastSuccess: 0, stale: false, errorKind: "" }; }

function staleSection(section, kind) {
    return { data: section.data, lastSuccess: section.lastSuccess, stale: section.data !== null, errorKind: kind };
}

function workSearches(login, kind) {
    var base = (kind === "prs" ? "is:pr" : "is:issue") + " is:open ";
    var role = (kind === "prs" ? "review-requested:" : "assignee:") + login;
    return { authored: base + "author:" + login + " sort:updated-desc",
        secondary: base + role + " -author:" + login + " sort:updated-desc",
        overlap: base + "author:" + login + " " + role + " sort:updated-desc" };
}

function workGroups(data, identity, kind) {
    var prs = kind === "prs";
    var secondaryRole = prs ? "Review requested" : "Assigned";
    var labels = prs ? ["Authored PRs", "Review requests from other authors"] : ["Authored issues", "Assignments from other authors"];
    if (!data.overlap || !Array.isArray(data.overlap.nodes) || data.overlap.nodes.length > 10) return null;
    var overlap = Object.create(null);
    for (var o = 0; o < data.overlap.nodes.length; o++) {
        var match = data.overlap.nodes[o];
        if (!match || typeof match.id !== "string" || !match.id || overlap[match.id]) return null;
        overlap[match.id] = true;
    }
    var searches = workSearches(identity.login, kind);
    var seen = Object.create(null);
    var groups = [];
    for (var g = 0; g < 2; g++) {
        var key = g === 0 ? "authored" : "secondary";
        var connection = data[key];
        if (!connection || !validCount(connection.issueCount) || !Array.isArray(connection.nodes)
            || connection.nodes.length !== Math.min(10, connection.issueCount)) return null;
        var rows = [];
        for (var i = 0; i < connection.nodes.length; i++) {
            var node = connection.nodes[i];
            if (!node || node.__typename !== (prs ? "PullRequest" : "Issue") || typeof node.id !== "string" || !node.id || seen[node.id]
                || node.state !== "OPEN" || !validCount(node.number) || node.number === 0
                || typeof node.title !== "string" || typeof node.updatedAt !== "string" || !isFinite(Date.parse(node.updatedAt))
                || (prs && typeof node.isDraft !== "boolean") || !node.repository || typeof node.repository.isPrivate !== "boolean"
                || typeof node.repository.nameWithOwner !== "string" || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(node.repository.nameWithOwner)
                || node.url !== "https://github.com/" + node.repository.nameWithOwner + (prs ? "/pull/" : "/issues/") + node.number) return null;
            var authored = node.author && typeof node.author.login === "string" && node.author.login.toLowerCase() === identity.login.toLowerCase();
            if (Boolean(authored) !== (g === 0)) return null;
            seen[node.id] = true;
            rows.push({ id: node.id, title: node.title, number: node.number, url: node.url, updatedAt: node.updatedAt,
                repository: node.repository.nameWithOwner, isPrivate: node.repository.isPrivate, isDraft: prs && node.isDraft,
                role: g === 0 ? "Authored" + (overlap[node.id] ? " · " + secondaryRole : "") : secondaryRole });
        }
        rows.sort(function(a, b) { return Date.parse(b.updatedAt) - Date.parse(a.updatedAt); });
        groups.push({ label: labels[g], total: connection.issueCount,
            rows: rows, url: "https://github.com/search?q=" + encodeURIComponent(searches[key]) + (prs ? "&type=pullrequests" : "&type=issues") });
    }
    return groups;
}

function Service(now) {
    this.identity = null;
    this.calendar = null;
    this.stats = null;
    this.repositories = sectionState();
    this.prs = sectionState();
    this.issues = sectionState();
    this.repositoryScan = null;
    this.lastSuccess = 0;
    this.stale = false;
    this.errorKind = "";
    this.retryAt = 0;
    this.active = null;
    this.serial = 0;
    this.day = utcDate(now);
    this.nextRefresh = now;
    this.rolloverPending = false;
}

Service.prototype.todayCount = function(now) {
    var day = this.calendar && this.calendar[utcDate(now)];
    return day ? day.contributionCount : null;
};

Service.prototype.refresh = function(now) {
    if (this.active || now < this.retryAt) return null;
    this.active = { id: ++this.serial, kind: "identity", at: now, command: command(identityQuery, {}) };
    return this.active;
};

Service.prototype.clearAccount = function() {
    this.identity = null;
    this.calendar = null;
    this.stats = null;
    this.repositories = sectionState();
    this.prs = sectionState();
    this.issues = sectionState();
    this.repositoryScan = null;
    this.lastSuccess = 0;
    this.stale = false;
};

Service.prototype.fail = function(kind, now) {
    var repositoryFailure = this.active && (this.active.kind === "repositories" || this.active.kind === "languages");
    var prFailure = this.active && this.active.kind === "prs";
    var issueFailure = this.active && this.active.kind === "issues";
    this.active = null;
    this.repositoryScan = null;
    this.errorKind = kind;
    if (!repositoryFailure && !prFailure && !issueFailure) this.stale = this.calendar !== null;
    if (!prFailure && !issueFailure) this.repositories = staleSection(this.repositories, kind);
    if (!issueFailure) this.prs = staleSection(this.prs, kind);
    this.issues = staleSection(this.issues, kind);
    this.nextRefresh = kind === "rate-limit" ? this.retryAt : now + refreshInterval;
    this.rolloverPending = false;
    if (kind === "authentication" || kind === "account") this.clearAccount();
    return null;
};

Service.prototype.workRequest = function(kind, at) {
    this.active = { id: ++this.serial, kind: kind, at: at, identity: this.identity,
        command: command(workQuery(kind), workSearches(this.identity.login, kind)) };
    return this.active;
};

Service.prototype.repositoryRequest = function(step, at) {
    var fields = step.kind === "repositories" ? { login: this.identity.login } : { id: step.id, languageCursor: step.cursor };
    if (step.kind === "repositories" && step.cursor) fields.cursor = step.cursor;
    this.active = { id: ++this.serial, kind: step.kind, at: at, identity: this.identity,
        command: command(step.kind === "repositories" ? repositoryQuery : languageQuery, fields) };
    return this.active;
};

Service.prototype.finishRefresh = function(now) {
    this.active = null;
    this.nextRefresh = now + refreshInterval;
    if (this.rolloverPending) {
        this.rolloverPending = false;
        return this.refresh(now);
    }
    return null;
};

Service.prototype.complete = function(id, result, now) {
    if (!this.active || this.active.id !== id) return null;
    var request = this.active;
    var decoded = decode(result);
    // GraphQL can return a viewer alongside section errors. An observed
    // account change invalidates cached data even when this refresh fails.
    var viewer = decoded.body && decoded.body.data && decoded.body.data.viewer;
    if (validIdentity(viewer) && this.identity && !sameIdentity(this.identity, viewer)) this.clearAccount();
    var failure = failureKind(result, decoded);
    if (failure) {
        if (failure === "rate-limit") this.retryAt = retryTime(decoded, now);
        return this.fail(failure, now);
    }
    var data = decoded.body.data;
    if (request.kind === "identity") {
        if (!validIdentity(data.viewer)) return this.fail("response", now);
        if (!sameIdentity(this.identity, data.viewer)) this.clearAccount();
        this.identity = data.viewer;
        this.active = { id: ++this.serial, kind: "calendar", at: request.at,
            identity: this.identity,
            command: command(calendarQuery, { login: data.viewer.login, from: annualStart(request.at),
                weekFrom: periodStart(request.at, 7), monthFrom: periodStart(request.at, 30),
                to: new Date(request.at).toISOString() }) };
        return this.active;
    }
    if (!sameIdentity(request.identity, data.viewer)
        || request.kind !== "languages" && request.kind !== "prs" && request.kind !== "issues" && !sameIdentity(request.identity, data.user))
        return this.fail("account", now);
    if (request.kind === "prs" || request.kind === "issues") {
        var groups = workGroups(data, request.identity, request.kind);
        if (!groups) return this.fail("response", now);
        this[request.kind] = { data: { groups: groups }, lastSuccess: now, stale: false, errorKind: "" };
        return request.kind === "prs" ? this.workRequest("issues", request.at) : this.finishRefresh(now);
    }
    if (request.kind === "repositories" || request.kind === "languages") {
        var valid;
        if (request.kind === "repositories") valid = this.repositoryScan.repositories(data.user.repositories);
        else {
            var repository = this.repositoryScan.pendingLanguages[0];
            valid = data.node && data.node.id === repository.id && data.node.isFork === false
                && sameIdentity(request.identity, data.node.owner) && this.repositoryScan.languages(data.node.languages, repository);
            if (valid && !repository.page.more) this.repositoryScan.pendingLanguages.shift();
        }
        if (!valid) return this.fail("response", now);
        var step = this.repositoryScan.next();
        if (step) return this.repositoryRequest(step, request.at);
        this.repositories = { data: this.repositoryScan.snapshot(), lastSuccess: now, stale: false, errorKind: "" };
        this.repositoryScan = null;
        return this.workRequest("prs", request.at);
    }
    var days = calendarDays(data.user);
    if (days === null) return this.fail("response", now);
    var stats = accountStats(days, data.user, request.at);
    if (stats === null) return this.fail("response", now);
    this.calendar = days;
    this.stats = stats;
    this.lastSuccess = now;
    this.stale = false;
    this.errorKind = "";
    this.retryAt = 0;
    this.repositoryScan = new RepositoryScan(this.identity);
    return this.repositoryRequest(this.repositoryScan.next(), request.at);
};

Service.prototype.tick = function(now) {
    if (utcDate(now) !== this.day) {
        this.day = utcDate(now);
        this.nextRefresh = now;
        if (this.active) this.rolloverPending = true;
    }
    return now >= this.nextRefresh ? this.refresh(now) : null;
};

Service.prototype.statusText = function(now) {
    if (this.active) return "Refreshing GitHub activity…";
    var messages = {
        gh: "GitHub CLI is missing or nonfunctional. Check gh on the shell's PATH.",
        authentication: "Authentication needed: run gh auth login --hostname github.com in a terminal.",
        permission: "The effective GitHub credentials cannot access the requested data. Check account access with gh auth status --hostname github.com.",
        network: "Cannot reach GitHub. Check the network connection.",
        timeout: "GitHub request timed out. Try Refresh when connectivity returns.",
        response: "GitHub returned an incomplete or invalid response. Press Refresh to try again.",
        account: "The effective GitHub account changed during refresh. Refresh to load the new account.",
        "rate-limit": "GitHub rate limit reached. Waiting before retrying."
    };
    if (this.errorKind === "rate-limit" && this.retryAt > now)
        return "GitHub rate limit reached. Retry after " + new Date(this.retryAt).toLocaleString() + ".";
    if (this.errorKind) return messages[this.errorKind];
    if (this.calendar && Object.keys(this.calendar).length === 0) return "GitHub returned no contribution dates.";
    if (this.calendar && this.todayCount(now) === null) return "Today's UTC contribution count is unavailable until refreshed.";
    return this.lastSuccess > 0 ? "GitHub contributions loaded." : "Waiting for GitHub contributions.";
};
