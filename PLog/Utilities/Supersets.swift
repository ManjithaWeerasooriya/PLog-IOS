//
//  Supersets.swift
//  PLog
//
//  Superset grouping shared by a session's exercises (`ExerciseEntry`) and a plan day's
//  slots (`PlanExercise`). A superset is a run of *adjacent* members sharing a
//  `supersetID`; the ID only has to be unique within its list. Lists are shown as
//  `blocks` — a plain exercise, or a whole superset merged into one row — and every
//  mutation here ends in `normalize`, so a lone member never keeps an ID and two runs
//  never share one.
//

import Foundation
import SwiftData

protocol SupersetMember: PersistentModel {
    var supersetID: UUID? { get set }
    var order: Int { get set }
}

extension ExerciseEntry: SupersetMember {}
extension PlanExercise: SupersetMember {}

/// One row-group in a list: a plain exercise (one member) or a superset (two or more).
struct SupersetBlock<Member: SupersetMember>: Identifiable {
    let members: [Member]

    /// Every member's ID, so a block whose membership changes is a new view (its rows
    /// rebuild their per-exercise view models) while a plain reorder keeps identity.
    var id: [PersistentIdentifier] { members.map(\.persistentModelID) }
    var isSuperset: Bool { members.count > 1 }
    var first: Member { members[0] }
}

enum Supersets {
    /// The list as display blocks, in order.
    static func blocks<Member: SupersetMember>(in ordered: [Member]) -> [SupersetBlock<Member>] {
        runs(in: ordered).map(SupersetBlock.init)
    }

    /// "A", "B", … for a member's position within its superset.
    static func letter(for index: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return index < alphabet.count
            ? String(alphabet[index])
            : letter(for: index / alphabet.count - 1) + String(alphabet[index % alphabet.count])
    }

    /// The block next to `block` in `direction`, which it could be merged with.
    static func neighbor<Member: SupersetMember>(
        of block: SupersetBlock<Member>,
        _ direction: Direction,
        in ordered: [Member]
    ) -> SupersetBlock<Member>? {
        let all = blocks(in: ordered)
        guard let index = all.firstIndex(where: { $0.id == block.id }) else { return nil }
        let neighborIndex = direction == .previous ? index - 1 : index + 1
        return all.indices.contains(neighborIndex) ? all[neighborIndex] : nil
    }

    /// Merges `block` with its neighbour into one superset — either side may already be one.
    static func join<Member: SupersetMember>(
        _ block: SupersetBlock<Member>,
        with direction: Direction,
        in ordered: [Member]
    ) {
        guard let other = neighbor(of: block, direction, in: ordered) else { return }
        let id = block.first.supersetID ?? other.first.supersetID ?? UUID()
        for member in block.members + other.members {
            member.supersetID = id
        }
        normalize(ordered)
    }

    /// The ID a new member should take to join `block` — minting one (and giving it to a
    /// plain exercise) when the block isn't a superset yet.
    static func idForJoining<Member: SupersetMember>(_ block: SupersetBlock<Member>) -> UUID {
        if let id = block.first.supersetID { return id }
        let id = UUID()
        block.first.supersetID = id
        return id
    }

    /// Links a freshly added `member` into `block`, placing it straight after the block's
    /// last member — "Superset with New Exercise…" on a plain row, or growing a superset.
    static func insert<Member: SupersetMember>(
        _ member: Member,
        joining block: SupersetBlock<Member>,
        in ordered: [Member]
    ) {
        member.supersetID = idForJoining(block)
        var reordered = ordered.filter { $0 !== member }
        let insertAt = (reordered.firstIndex { $0 === block.members.last } ?? reordered.count - 1) + 1
        reordered.insert(member, at: insertAt)
        renumber(reordered)
        normalize(reordered)
    }

    /// Takes `member` out of its superset and places it straight after what's left, so the
    /// rest stay together rather than being split around it. Returns the new order.
    @discardableResult
    static func remove<Member: SupersetMember>(_ member: Member, in ordered: [Member]) -> [Member] {
        guard let block = blocks(in: ordered).first(where: { $0.members.contains { $0 === member } }),
              block.isSuperset else { return ordered }
        var reordered = ordered.filter { $0 !== member }
        let lastRemaining = block.members.last { $0 !== member }
        let insertAt = (reordered.firstIndex { $0 === lastRemaining } ?? reordered.count - 1) + 1
        reordered.insert(member, at: insertAt)
        member.supersetID = nil
        renumber(reordered)
        normalize(reordered)
        return reordered
    }

    /// Splits a superset back into plain exercises, in place.
    static func ungroup<Member: SupersetMember>(_ block: SupersetBlock<Member>, in ordered: [Member]) {
        for member in block.members {
            member.supersetID = nil
        }
        normalize(ordered)
    }

    /// Reorders whole blocks (a superset moves as one) and renumbers `order`.
    static func moveBlocks<Member: SupersetMember>(
        in ordered: [Member],
        from source: IndexSet,
        to destination: Int
    ) {
        // `move(fromOffsets:toOffset:)` semantics, without importing SwiftUI here.
        let all = blocks(in: ordered)
        let moving = source.map { all[$0] }
        var staying = all.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        staying.insert(contentsOf: moving, at: destination - source.filter { $0 < destination }.count)
        let reordered = staying.flatMap(\.members)
        renumber(reordered)
        normalize(reordered)
    }

    /// Clears the ID of any member left on its own, and gives a run a fresh ID when an
    /// earlier run already uses its ID — otherwise the two would merge if they became
    /// adjacent later.
    static func normalize<Member: SupersetMember>(_ ordered: [Member]) {
        var seen: Set<UUID> = []
        for run in runs(in: ordered) {
            guard let id = run.first?.supersetID else { continue }
            if run.count == 1 {
                run[0].supersetID = nil
            } else if seen.contains(id) {
                let fresh = UUID()
                for member in run { member.supersetID = fresh }
                seen.insert(fresh)
            } else {
                seen.insert(id)
            }
        }
    }

    static func renumber<Member: SupersetMember>(_ ordered: [Member]) {
        for (index, member) in ordered.enumerated() {
            member.order = index
        }
    }

    enum Direction {
        case previous, next
    }

    // MARK: - Helpers

    /// Consecutive members sharing a non-nil ID; every member without one is its own run.
    private static func runs<Member: SupersetMember>(in ordered: [Member]) -> [[Member]] {
        ordered.reduce(into: []) { runs, member in
            if let id = member.supersetID, let last = runs.last?.last, last.supersetID == id {
                runs[runs.count - 1].append(member)
            } else {
                runs.append([member])
            }
        }
    }
}
