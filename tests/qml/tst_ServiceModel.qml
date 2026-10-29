import QtQuick
import QtTest
import "../../ServiceModel.js" as Model

TestCase {
    name: "ServiceModelQmlRuntime"

    function test_calendarRefresh() {
        var now = Date.parse("2026-10-25T09:00:00Z")
        var service = new Model.Service(now)
        var identity = { id: "U_fixture", login: "fixture" }
        var request = service.refresh(now)
        var next = service.complete(request.id, { code: 0, stdout: JSON.stringify({ data: { viewer: identity } }) }, now)
        verify(next.command.indexOf("login=fixture") >= 0)
        var days = []
        for (var offset = 369; offset >= 0; offset--) days.push({
            date: new Date(now - offset * 86400000).toISOString().slice(0, 10),
            contributionCount: 0, contributionLevel: "NONE"
        })
        var totals = { totalCommitContributions: 0, totalPullRequestContributions: 0, totalIssueContributions: 0, restrictedContributionsCount: 0 }
        service.complete(next.id, { code: 0, stdout: JSON.stringify({ data: {
            viewer: identity, user: { id: identity.id, login: identity.login,
                week: totals, month: totals, contributionsCollection: {
                    totalCommitContributions: 0, totalPullRequestContributions: 0, totalIssueContributions: 0, restrictedContributionsCount: 0,
                    contributionCalendar: { weeks: [{ contributionDays: days }] }
                } }
        } }) }, now)
        compare(service.todayCount(now), 0)
        compare(service.lastSuccess, now)
        compare(service.todayCount(now + 86400000), null)
        compare(service.stats.periods.week.days.length, 7)
        compare(service.stats.periods.week.contributions, 0)
    }
}
