// @flow
import { Map, Record } from 'immutable';

import { Location } from './Location';

export const UpLevel = Symbol('UpLevel');

// Need multiple paths to point to the same location.
//
// Example: `f` is used in several eliminations. When one place changes `f` all
// the others need to as well.
//
// What are two example paths leading to `f`?
// * ['A', 'field0', 'eliminator']
// * ['A', 'field1', 'eliminator']
//
// Why do we need Firmament? Just point directly to Locations. Firmament is
// immutable / allows us to undo.
//
// Why Symbols? Why not return Locations? Good question.
//
// So what's novel about this data structure?
// * No longer the path thing -- paths are now just chained pointers
// * UpLevel  are special
// * ty is special (it's implicitly the type of types) Do we need this?
//   Probably not -- just have all types point to ty's location!
// * Change bubbling
//   - How to prevent ty from bubbling to itself repeatedly?
//   - Maybe changes only bubble if you change, which can't happen for ty

export type Step = string|Symbol;

export type Path = {
  root: Symbol; // TODO root type
  steps: Array<Step>;
};

export type WithGlobal<A> = {
  global: Firmament;
  it: A;
};

// TODO: might be cool to make a Locations class which extends Map with
// operations... problem is i'm not sure what those operations might be

const FirmamentShape = Record({
  tyPointer: null,
  holePointer: null,
  memory: null,
});

export default class Firmament extends FirmamentShape {
  tyPointer: Symbol;
  memory: Map<Symbol, Location>;

  constructor(tyVal: any, holeVal: any): void {
    // TODO can't we initialize these in Record arguments?
    const tyPointer = Symbol();
    const holePointer = Symbol();
    const memory = Map([
      [ tyPointer, new Location({ tag: tyVal }) ],
      [ holePointer, new Location({ tag: holeVal }) ],
    ]);
    super({ tyPointer, holePointer, memory });
    // XXX tie the knot -- set the types of Hole and Ty
  }

  followPath({ root, steps }: Path): Symbol {
    let nextLoc = root;

    for (const step: Step of steps) {
      const loc: Location = this.getLocation(nextLoc);
      nextLoc = loc.locations.get(step);
    }

    return nextLoc;
  }

  getPath(path: Path): Location {
    return this.getLocation(this.followPath(path));
  }

  getLocation(pointer: Symbol): Location {
    return this.memory.get(pointer);
  }

  // find every location pointing to pointer
  getReferers(pointer: Symbol): Array<[Symbol, string]> {
    const targets = [];

    for (const [symbol] of this.memory) {
      const loc = this.getLocation(symbol);
      for (const [ name, locPointer ] of loc.locations) {
        if (locPointer === pointer) {
          targets.push([symbol, name]);
          break;
        }
      }
    }

    return targets;
  }

  update(pointer: Symbol, val: Location): Firmament {
    return this.setIn(['memory', pointer], val);
  }

  newLocation(
    val: { tag: Symbol, data: Object, locations: ?Object }
  ): WithGlobal<Symbol> {
    const it = Symbol();
    const global = this.update(it, new Location(val));
    return { it, global };
  }
}