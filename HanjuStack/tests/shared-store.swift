import Foundation

@main struct SharedStoreChecks {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = HanjuStore(url: folder.appendingPathComponent("state.json"))
        let widget = HanjuStore(url: app.url)
        let empty = try app.read(); precondition(empty == nil)
        let initial: [String: Any] = ["v":3,"blocks":[["id":"task","name":"Class","start":20,"len":2,"date":"2026-10-30","done":false]],"fixed":[],"theme":"light"]
        let one = try app.update(expected:0) { _ in initial }
        precondition(HanjuStore.revision(one) == 1)
        _ = try widget.update { current in
            var root = current!, rows = root["blocks"] as! [[String:Any]]
            rows[0]["done"] = true; root["blocks"] = rows; return root
        }
        do { _ = try app.update(expected:1) { _ in initial }; fatalError("Stale app replaced widget changes") }
        catch HanjuStore.StoreError.stale {}
        let state = try app.read()!, rows = state["blocks"] as! [[String:Any]]
        precondition(rows[0]["done"] as? Bool == true && rows[0]["start"] as? Int == 20 && rows[0]["len"] as? Int == 2)
        precondition(HanjuStore.revision(state) == 2)
        do { _ = try app.update { _ in ["blocks":"invalid"] }; fatalError("Invalid data accepted") }
        catch HanjuStore.StoreError.invalidData {}
        let unchanged = try app.read(); precondition(HanjuStore.revision(unchanged) == 2)
        let group = DispatchGroup(), lock = NSLock(); var failures = [String]()
        for _ in 0..<20 {
            group.enter(); DispatchQueue.global().async {
                defer { group.leave() }
                do { let writer = HanjuStore(url: app.url); try writer.update { current in var root=current!;root["counter"]=(root["counter"] as? Int ?? 0)+1;return root } }
                catch { lock.lock(); failures.append(error.localizedDescription); lock.unlock() }
            }
        }
        group.wait()
        let final = try app.read(); precondition(failures.isEmpty && (final?["counter"] as? Int) == 20)
        print("PASS: shared app/widget state, stale-write rejection, valid data preservation, invalid-write rollback and 20 concurrent coordinated updates")
    }
}
