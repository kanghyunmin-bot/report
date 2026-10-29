import Foundation

struct CompanionGoal: Equatable {
 let id: String
 let day: String
 let subject: String
 let title: String
 let status: Int
}

struct CompanionSnapshot {
 let goals: [CompanionGoal]
 var hasWork: Bool { goals.contains { $0.status == 1 } }
 static func read(_ state: [String: Any], plan: [[Any]], today: String) -> CompanionSnapshot {
  let statuses = state["status"] as? [String: Int] ?? [:]
  let deleted = state["deleted"] as? [String: Bool] ?? [:]
  let edits = state["edits"] as? [String: [String: String]] ?? [:]
  var goals: [CompanionGoal] = []; var seen = Set<String>()
  func append(id: String, day: String, subject: String, title: String) {
   guard deleted[id] != true, seen.insert(id).inserted else { return }
   let status = statuses[id] ?? 0, edit = edits[id] ?? [:]
   goals.append(CompanionGoal(id:id, day:day < today && status == 1 ? today:day,
     subject:edit["subject"] ?? subject, title:edit["title"] ?? title, status:status))
  }
  for row in plan {
   guard row.count == 3, let day = row[0] as? String, let items = row[2] as? [[String]] else { continue }
   for (i, item) in items.enumerated() where item.count >= 2 {
    append(id:"\(day)-\(i)",day:day,subject:item[0],title:item[1])
   }
  }
  for (day, items) in (state["extra"] as? [String: [[String: Any]]] ?? [:]).sorted(by:{$0.key < $1.key}) {
   for item in items {
    guard let id = item["id"] as? String, let title = item["title"] as? String else { continue }
    append(id:id,day:day,subject:item["subject"] as? String ?? "할 일",title:title)
   }
  }
  return CompanionSnapshot(goals:goals.sorted {
   if ($0.status == 1) != ($1.status == 1) { return $0.status == 1 }
   if $0.day != $1.day { return $0.day < $1.day }
   return $0.id < $1.id
  })
 }
}

enum CompanionMode: String { case idle, working, complete }
struct CompanionPresentation {
 let mode: CompanionMode
 let elapsed: Double
 let celebrationNumber: Int
}

/// Monotonic time and explicit completion edges prevent replay on launch/save.
final class CompanionPlayback {
 static let celebrationLoops = 5
 static let completeSeconds = 1.5
 private(set) var snapshot = CompanionSnapshot(goals:[])
 private(set) var queue: [String] = []
 private var previous: [String: Int]?
 private var celebrationStart: Double?
 private var modeStart: Double = 0
 private var baseMode: CompanionMode = .idle

 func update(_ next: CompanionSnapshot, at now: Double) {
  let statuses = Dictionary(next.goals.map { ($0.id,$0.status) },uniquingKeysWith:{$1})
  let wasFirst = queue.first
  if let previous {
   for goal in next.goals where goal.status == 2 && previous[goal.id] != nil && previous[goal.id] != 2 {
    queue.append(goal.id)
   }
  }
  // Undo/deletion cancels that task's pending celebration, not another task's.
  queue.removeAll { statuses[$0] != 2 }
  if queue.isEmpty { celebrationStart = nil }
  else if celebrationStart == nil || wasFirst != queue.first { celebrationStart = now }
  previous = statuses; snapshot = next
  let mode: CompanionMode = next.hasWork ? .working:.idle
  if mode != baseMode { baseMode = mode; modeStart = now }
 }

 func presentation(at now: Double) -> CompanionPresentation {
  let duration = Self.completeSeconds * Double(Self.celebrationLoops)
  while let start = celebrationStart, now - start >= duration - 0.0000001 {
   if !queue.isEmpty { queue.removeFirst() }
   if queue.isEmpty { celebrationStart = nil; modeStart = now }
   else { celebrationStart = start + duration }
  }
  if let start = celebrationStart {
   let elapsed = max(0, now-start)
   return CompanionPresentation(mode:.complete,elapsed:elapsed,
     celebrationNumber:min(Self.celebrationLoops,Int((elapsed+0.0000001)/Self.completeSeconds)+1))
  }
  return CompanionPresentation(mode:baseMode,elapsed:max(0,now-modeStart),celebrationNumber:0)
 }

 static func frame(at seconds: Double, milliseconds: [Int]) -> Int {
  guard !milliseconds.isEmpty else { return 0 }
  let total = milliseconds.reduce(0,+)
  guard total > 0 else { return 0 }
  var position = (max(0,seconds)*1000+0.00001).truncatingRemainder(dividingBy:Double(total))
  for (i,duration) in milliseconds.enumerated() {
   if position < Double(duration) { return i }
   position -= Double(duration)
  }
  return 0
 }
}
