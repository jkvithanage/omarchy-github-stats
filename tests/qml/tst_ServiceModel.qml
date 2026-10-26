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
        service.complete(next.id, { code: 0, stdout: JSON.stringify({ data: {
            viewer: identity, user: { id: identity.id, login: identity.login, contributionsCollection: {
                contributionCalendar: { weeks: [{ contributionDays: [
                    { date: "2026-10-25", contributionCount: 0, contributionLevel: "NONE" }
                ] }] }
            } }
        } }) }, now)
        compare(service.todayCount(now), 0)
        compare(service.lastSuccess, now)
        compare(service.todayCount(now + 86400000), null)
    }
}
