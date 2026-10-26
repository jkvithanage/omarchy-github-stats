const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');

const model = vm.createContext({});
vm.runInContext(readFileSync('ServiceModel.js', 'utf8'), model);
const instant = Date.parse('2026-10-25T09:00:00Z');
const alice = { id: 'U_alice', login: 'alice' };
function response(data) { return { code: 0, stdout: JSON.stringify({ data }), stderr: '' }; }
function calendar(identity = alice, days, now = instant) {
    const end = Date.parse(new Date(now).toISOString().slice(0, 10) + 'T00:00:00Z');
    const returned = Array.from({ length: 370 }, (_, i) => ({
        date: new Date(end - (369 - i) * 86400000).toISOString().slice(0, 10),
        contributionCount: 0, contributionLevel: 'NONE'
    }));
    for (const day of days || [{ date: '2026-10-25', contributionCount: 8, contributionLevel: 'SECOND_QUARTILE' }]) {
        const index = returned.findIndex(value => value.date === day.date);
        if (index >= 0) returned[index] = day;
        else returned.push(day);
    }
    const totals = { totalCommitContributions: 3, totalPullRequestContributions: 2, totalIssueContributions: 1 };
    return response({ viewer: identity, user: { ...identity, contributionsCollection: {
        ...totals, contributionCalendar: { weeks: [{ contributionDays: returned }] }
    }, week: totals, month: { totalCommitContributions: 13, totalPullRequestContributions: 12, totalIssueContributions: 11 } } });
}
function load(service, now = instant, identity = alice, days) {
    const identityRequest = service.refresh(now);
    const dataRequest = service.complete(identityRequest.id, response({ viewer: identity }), now);
    service.complete(dataRequest.id, calendar(identity, days, now), now);
}

test('Stats refresh requests all period summaries with one UTC end instant', () => {
    const now = Date.parse('2024-02-29T12:34:56Z');
    const service = new model.Service(now);
    const request = service.refresh(now);
    const next = service.complete(request.id, response({ viewer: alice }), now + 1000);
    assert.ok(next.command.includes('weekFrom=2024-02-23T00:00:00.000Z'));
    assert.ok(next.command.includes('monthFrom=2024-01-31T00:00:00.000Z'));
    assert.ok(next.command.includes('from=2023-03-01T00:00:00.000Z'));
    assert.ok(next.command.includes('to=2024-02-29T12:34:56.000Z'));
    const query = next.command.find(arg => arg.startsWith('query='));
    assert.match(query, /week: contributionsCollection\(from: \$weekFrom, to: \$to\)/);
    assert.match(query, /month: contributionsCollection\(from: \$monthFrom, to: \$to\)/);
    for (const field of ['totalCommitContributions', 'totalPullRequestContributions', 'totalIssueContributions']) {
        assert.equal(query.split(field).length - 1, 3, field);
    }
});

test('Stats publishes seven chronological dates and independent activity summaries atomically', () => {
    const service = new model.Service(instant);
    const request = service.refresh(instant);
    const next = service.complete(request.id, response({ viewer: alice }), instant + 1000);
    assert.equal(service.stats, null);
    service.complete(next.id, calendar(), instant + 2000);
    assert.equal(service.stats.at, instant);
    const week = service.stats.periods.week;
    assert.deepEqual(Array.from(week.days, day => day.date), [
        '2026-10-19', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23', '2026-10-24', '2026-10-25'
    ]);
    assert.equal(week.days[0].contributionCount, 0);
    assert.equal(week.days[0].contributionLevel, 'NONE');
    assert.equal(week.days[6].contributionLevel, 'SECOND_QUARTILE');
    assert.equal(week.contributions, 8);
    assert.equal(week.commitContributions, 3);
    assert.equal(week.prsAuthored, 2);
    assert.equal(week.issuesAuthored, 1);
    assert.equal(week.from, '2026-10-19T00:00:00.000Z');
    assert.equal(week.to, '2026-10-25T09:00:00.000Z');
    assert.equal(service.stats.periods.month.commitContributions, 13);
    assert.equal(service.stats.periods.year.days.length, 365);
});

test('period dates cross UTC month, year and leap boundaries without changing annual levels', () => {
    for (const [date, weekStart, monthStart, yearStart, length] of [
        ['2026-01-01T00:00:00Z', '2025-12-26', '2025-12-03', '2025-01-02', 365],
        ['2024-03-01T00:00:00Z', '2024-02-24', '2024-02-01', '2023-03-02', 366],
        ['2024-02-29T23:59:59Z', '2024-02-23', '2024-01-31', '2023-03-01', 366],
        ['2025-02-28T09:00:00Z', '2025-02-22', '2025-01-30', '2024-02-29', 366]
    ]) {
        const now = Date.parse(date);
        const service = new model.Service(now);
        const day = { date: date.slice(0, 10), contributionCount: 17, contributionLevel: 'FOURTH_QUARTILE' };
        load(service, now, alice, [day]);
        assert.ok(service.stats, date);
        const { week, month, year } = service.stats.periods;
        assert.equal(week.days[0].date, weekStart);
        assert.equal(month.days[0].date, monthStart);
        assert.equal(year.days[0].date, yearStart);
        assert.equal(year.days.length, length);
        assert.equal(week.days[6], year.days.at(-1));
        assert.equal(month.days[29].contributionLevel, 'FOURTH_QUARTILE');
        assert.equal(week.contributions, 17);
    }
});

test('incomplete Stats responses retain the entire last snapshot and original freshness', () => {
    const service = new model.Service(instant);
    load(service);
    const snapshot = service.stats;
    const mutations = [
        data => { delete data.user.week; },
        data => { data.user.month.totalCommitContributions = null; },
        data => { data.user.contributionsCollection.totalIssueContributions = -1; },
        data => { data.user.week.totalPullRequestContributions = '0'; },
        data => { data.user.contributionsCollection.contributionCalendar.weeks[0].contributionDays.pop(); },
        data => { data.user.contributionsCollection.contributionCalendar.weeks[0].contributionDays.splice(5, 1); }
    ];
    for (const mutate of mutations) {
        const first = service.refresh(instant + 1000);
        const next = service.complete(first.id, response({ viewer: alice }), instant + 1000);
        const { data } = JSON.parse(calendar().stdout);
        mutate(data);
        service.complete(next.id, response(data), instant + 2000);
        assert.equal(service.errorKind, 'response');
        assert.equal(service.stats, snapshot);
        assert.equal(service.lastSuccess, instant);
        assert.equal(service.stale, true);
        assert.equal(service.todayCount(instant), 8);
    }
    const first = service.refresh(instant + 3000);
    service.complete(first.id, { code: 1, stdout: 'HTTP/2.0 401 Unauthorized\n\n{}' }, instant + 3000);
    assert.equal(service.stats, null);
});

test('shared consumers see the same successful UTC count and freshness', () => {
    const service = new model.Service(instant);
    const consumers = [service, service];
    load(service);
    assert.deepEqual(consumers.map(s => s.todayCount(instant)), [8, 8]);
    assert.equal(service.lastSuccess, instant);
    assert.equal(service.stale, false);
    assert.equal(service.calendar['2026-10-25'].contributionLevel, 'SECOND_QUARTILE');
});

test('overlapping consumers coalesce refreshes and superseded results cannot publish', () => {
    const service = new model.Service(instant);
    const first = service.refresh(instant);
    assert.equal(service.refresh(instant + 1), null);
    const second = service.complete(first.id, response({ viewer: alice }), instant);
    service.complete(first.id, calendar(), instant);
    assert.equal(service.calendar, null);
    service.complete(second.id, calendar(), instant);
    assert.equal(service.todayCount(instant), 8);
    assert.equal(service.tick(instant + 899999), null);
    assert.ok(service.tick(instant + 900000));
});

test('UTC rollover hides yesterday and queues one refresh after an in-flight old-day request', () => {
    const before = Date.parse('2026-12-31T23:59:59Z');
    const after = before + 2000;
    const service = new model.Service(before);
    load(service, before, alice, [{ date: '2026-12-31', contributionCount: 4, contributionLevel: 'FIRST_QUARTILE' }]);
    const identity = service.refresh(before);
    const old = service.complete(identity.id, response({ viewer: alice }), before);
    assert.equal(service.tick(after), null);
    assert.equal(service.todayCount(after), null);
    const next = service.complete(old.id, calendar(alice, [{ date: '2026-12-31', contributionCount: 5, contributionLevel: 'FIRST_QUARTILE' }], before), after);
    assert.ok(next, 'rollover must not wait fifteen minutes after an old-day refresh');
    assert.equal(next.kind, 'identity');
    assert.equal(service.tick(after + 1), null);
});

test('identity changes clear old data before the new calendar arrives', () => {
    const service = new model.Service(instant);
    load(service);
    const request = service.refresh(instant + 1000);
    const bob = { id: 'U_bob', login: 'bob' };
    const next = service.complete(request.id, response({ viewer: bob }), instant + 1000);
    assert.equal(service.todayCount(instant), null);
    assert.equal(service.lastSuccess, 0);
    assert.equal(service.identity.login, 'bob');
    assert.ok(next.command.includes('login=bob'));
    service.complete(next.id, calendar(bob), instant + 1000);
    assert.equal(service.todayCount(instant), 8);
});

test('credentials changing during a data request cannot combine accounts', () => {
    const service = new model.Service(instant);
    load(service);
    const request = service.refresh(instant + 1000);
    const data = service.complete(request.id, response({ viewer: alice }), instant + 1000);
    const mixed = JSON.parse(calendar().stdout);
    mixed.data.viewer = { id: 'U_bob', login: 'bob' };
    const retry = service.complete(data.id, { code: 0, stdout: JSON.stringify(mixed) }, instant + 1000);
    assert.equal(service.calendar, null);
    assert.equal(service.identity, null);
    assert.equal(service.lastSuccess, 0);
    assert.equal(retry, null, 'account churn must not trigger a tight retry loop');
    assert.equal(service.errorKind, 'account');
});

test('partial GraphQL failures still clear an observed previous account and respect retry guidance', () => {
    for (const phase of ['identity', 'calendar']) {
        for (const type of ['FORBIDDEN', 'RATE_LIMITED']) {
            const service = new model.Service(instant);
            load(service);
            let request = service.refresh(instant + 1000);
            if (phase === 'calendar') request = service.complete(request.id, response({ viewer: alice }), instant + 1000);
            service.complete(request.id, { code: 1, stdout: 'HTTP/2.0 200 OK\nRetry-After: 3600\n\n' + JSON.stringify({
                data: { viewer: { id: 'U_bob', login: 'bob' }, user: null }, errors: [{ type, message: type }]
            }) }, instant + 1000);
            assert.equal(service.calendar, null);
            assert.equal(service.identity, null);
            assert.equal(service.lastSuccess, 0);
            assert.equal(service.errorKind, type === 'FORBIDDEN' ? 'permission' : 'rate-limit');
            if (type === 'RATE_LIMITED') assert.equal(service.retryAt, instant + 3601000);
        }
    }
});

test('transient failures preserve stale data without advancing freshness; authentication loss clears it', () => {
    const cases = [
        ['network', { code: 1, stderr: 'error connecting to api.github.com: dial tcp: no such host' }],
        ['permission', { code: 1, stdout: 'HTTP/2.0 403 Forbidden\r\n\r\n{"message":"Resource not accessible by integration"}' }],
        ['timeout', { code: -1, failure: 'timeout' }],
        ['gh', { code: -1, failure: 'gh' }],
        ['gh', { code: 127, stderr: 'mise ERROR Failed to install cli: Read-only file system' }],
        ['response', { code: 0, stdout: 'invalid-json' }],
        ['authentication', { code: 1, stderr: 'To get started with GitHub CLI, please run: gh auth login' }],
        ['authentication', { code: 1, stdout: 'HTTP/2.0 401 Unauthorized\n\n{"message":"Bad credentials"}' }]
    ];
    for (const [kind, result] of cases) {
        const service = new model.Service(instant);
        load(service);
        const request = service.refresh(instant + 1000);
        assert.doesNotThrow(() => service.complete(request.id, result, instant + 1000), kind);
        assert.equal(service.errorKind, kind);
        assert.equal(service.active, null);
        if (kind === 'authentication') {
            assert.equal(service.calendar, null);
            assert.equal(service.identity, null);
            assert.equal(service.lastSuccess, 0);
            assert.match(service.statusText(instant), /gh auth login --hostname github.com/);
        } else {
            assert.equal(service.todayCount(instant), 8);
            assert.equal(service.lastSuccess, instant);
            assert.equal(service.stale, true);
        }
        assert.equal(service.tick(instant + 1001), null);
        service.complete(request.id, calendar(), instant + 2000);
        assert.equal(service.errorKind, kind, 'late completion must be ignored');
    }
});

test('zero-activity dates are successful; empty, malformed and partial calendars are not zeros', () => {
    const service = new model.Service(instant);
    load(service, instant, alice, []);
    assert.equal(service.errorKind, '');
    assert.equal(service.todayCount(instant), 0);
    assert.equal(service.lastSuccess, instant);
    load(service, instant + 1000, alice, [{ date: '2026-10-25', contributionCount: 0, contributionLevel: 'NONE' }]);
    assert.equal(service.todayCount(instant), 0);

    const malformed = [
        { viewer: alice, user: { ...alice, contributionsCollection: { contributionCalendar: { weeks: [] } } } },
        { viewer: alice, user: { ...alice } },
        { viewer: alice, user: { ...alice, contributionsCollection: { contributionCalendar: { weeks: [{ contributionDays: null }] } } } },
        JSON.parse(calendar(alice, [{ date: '2026-10-25', contributionCount: -1, contributionLevel: 'NONE' }]).stdout).data,
        JSON.parse(calendar(alice, [{ date: '2026-02-30', contributionCount: 0, contributionLevel: 'NONE' }]).stdout).data,
        JSON.parse(calendar(alice, [{ date: '2026-10-25', contributionCount: 1 }]).stdout).data,
    ];
    for (const data of malformed) {
        const request = service.refresh(instant + 2000);
        const next = service.complete(request.id, response({ viewer: alice }), instant + 2000);
        assert.doesNotThrow(() => service.complete(next.id, response(data), instant + 2000));
        assert.equal(service.errorKind, 'response');
        assert.equal(service.todayCount(instant), 0);
        assert.equal(service.lastSuccess, instant + 1000);
        assert.equal(service.stale, true);
    }
});

test('annual data requests use explicit host, effective login and clamped UTC bounds', () => {
    const now = Date.parse('2024-02-29T12:34:56Z');
    const service = new model.Service(now);
    const request = service.refresh(now);
    const next = service.complete(request.id, response({ viewer: alice }), now);
    assert.equal(next.command[0], 'gh');
    assert.ok(next.command.includes('--hostname'));
    assert.ok(next.command.includes('github.com'));
    assert.ok(next.command.includes('from=2023-03-01T00:00:00.000Z'));
    assert.ok(next.command.includes('to=2024-02-29T12:34:56.000Z'));
    assert.ok(next.command.includes('login=alice'));
    assert.ok(!next.command.includes('sh'));
});

test('rate limits honor Retry-After and reset guidance for all triggers while retaining useful data', () => {
    const retryDate = new Date(instant + 3600000).toUTCString();
    const reset = (instant + 7200000) / 1000;
    const cases = [
        ['HTTP/2.0 429 Too Many Requests\nRetry-After: 60\n\n{"message":"slow down"}', instant + 60000],
        ['HTTP/2.0 429 Too Many Requests\r\nRetry-After: 3600\r\n\r\n{"message":"slow down"}', instant + 3600000],
        [`HTTP/2.0 403 Forbidden\nRetry-After: ${retryDate}\nX-RateLimit-Remaining: 0\nX-RateLimit-Reset: ${reset}\n\n{"message":"API rate limit exceeded"}`, instant + 7200000],
        [JSON.stringify({ errors: [{ type: 'RATE_LIMITED', message: 'rate limit exceeded' }], data: { rateLimit: { resetAt: new Date(instant + 3600000).toISOString() } } }), instant + 3600000],
        ['HTTP/2.0 403 Forbidden\n\n{"message":"You have exceeded a secondary rate limit"}', instant + 900000]
    ];
    for (const [stdout, retryAt] of cases) {
        const service = new model.Service(instant);
        load(service);
        const request = service.refresh(instant);
        service.complete(request.id, { code: 1, stdout }, instant);
        assert.equal(service.errorKind, 'rate-limit');
        assert.equal(service.retryAt, retryAt);
        assert.equal(service.todayCount(instant), 8);
        assert.equal(service.lastSuccess, instant);
        assert.equal(service.stale, true);
        assert.equal(service.refresh(retryAt - 1), null);
        assert.equal(service.tick(retryAt - 1), null);
        assert.match(service.statusText(instant), /retry/i);
        assert.ok(service.tick(retryAt));
    }
});
