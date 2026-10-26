// In-memory service state. The QML adapter owns processes and the wall clock.
var refreshInterval = 15 * 60 * 1000;
var identityQuery = "query { viewer { id login } }";
var summaryFields = "totalCommitContributions totalPullRequestContributions totalIssueContributions ";
var calendarQuery = "query($login: String!, $from: DateTime!, $weekFrom: DateTime!, $monthFrom: DateTime!, $to: DateTime!) { "
    + "viewer { id login } user(login: $login) { id login "
    + "contributionsCollection(from: $from, to: $to) { " + summaryFields + "contributionCalendar { "
    + "weeks { contributionDays { date contributionCount contributionLevel } } } } "
    + "week: contributionsCollection(from: $weekFrom, to: $to) { " + summaryFields + "} "
    + "month: contributionsCollection(from: $monthFrom, to: $to) { " + summaryFields + "} } }";

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
        || !validCount(collection.totalPullRequestContributions) || !validCount(collection.totalIssueContributions)) return null;
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
        prsAuthored: collection.totalPullRequestContributions, issuesAuthored: collection.totalIssueContributions };
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

function Service(now) {
    this.identity = null;
    this.calendar = null;
    this.stats = null;
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
    this.lastSuccess = 0;
    this.stale = false;
};

Service.prototype.fail = function(kind, now) {
    this.active = null;
    this.errorKind = kind;
    this.stale = this.calendar !== null;
    this.nextRefresh = kind === "rate-limit" ? this.retryAt : now + refreshInterval;
    this.rolloverPending = false;
    if (kind === "authentication" || kind === "account") this.clearAccount();
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
    if (!sameIdentity(request.identity, data.viewer) || !sameIdentity(request.identity, data.user))
        return this.fail("account", now);
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
    this.active = null;
    this.nextRefresh = now + refreshInterval;
    if (this.rolloverPending) {
        this.rolloverPending = false;
        return this.refresh(now);
    }
    return null;
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
    if (this.active) return "Refreshing GitHub contributions…";
    var messages = {
        gh: "GitHub CLI is missing or nonfunctional. Check gh on the shell's PATH.",
        authentication: "Authentication needed: run gh auth login --hostname github.com in a terminal.",
        permission: "The effective GitHub credentials cannot access the requested data.",
        network: "Cannot reach GitHub. Check the network connection.",
        timeout: "GitHub request timed out. Try Refresh when connectivity returns.",
        response: "GitHub returned an incomplete or invalid response.",
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
