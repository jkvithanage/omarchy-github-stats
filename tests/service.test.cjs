const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');

const model = vm.createContext({});
vm.runInContext(readFileSync('ServiceModel.js', 'utf8'), model);
const instant = Date.parse('2026-10-25T09:00:00Z');
const alice = { id: 'U_alice', login: 'alice' };
function response(data) { return { code: 0, stdout: JSON.stringify({ data }), stderr: '' }; }
function calendar(identity = alice, days = [{ date: '2026-10-25', contributionCount: 8, contributionLevel: 'SECOND_QUARTILE' }]) {
    return response({ viewer: identity, user: { ...identity, contributionsCollection: {
        contributionCalendar: { weeks: [{ contributionDays: days }] }
    } } });
}
function load(service, now = instant, identity = alice, days) {
    const identityRequest = service.refresh(now);
    const dataRequest = service.complete(identityRequest.id, response({ viewer: identity }), now);
    service.complete(dataRequest.id, calendar(identity, days), now);
}

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
    const next = service.complete(old.id, calendar(alice, [{ date: '2026-12-31', contributionCount: 5, contributionLevel: 'FIRST_QUARTILE' }]), after);
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

test('empty and zero-activity calendars are successful; malformed and partial data are not zeros', () => {
    const service = new model.Service(instant);
    load(service, instant, alice, []);
    assert.equal(service.errorKind, '');
    assert.equal(service.todayCount(instant), null);
    assert.equal(service.lastSuccess, instant);
    assert.match(service.statusText(instant), /no.*dates/i);
    load(service, instant + 1000, alice, [{ date: '2026-10-25', contributionCount: 0, contributionLevel: 'NONE' }]);
    assert.equal(service.todayCount(instant), 0);

    const malformed = [
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
