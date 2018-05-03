# TimeMachine

An implementation of a pomodoro timer in elixir, which renders to js

the intent is to show how the interface can be made entirely in elixir, then
regular js can listen for the events from the interface and do stuff, but the
interface should be easily renderable by phoenix and operate properly without
any of the bindings.

## Implementation notes

#### template
- ex:
  - only the *last statement* in the do-block gets put into the content (has optional assigns)
  - defines a function
- js:
  - creates an anon wrapper function which defines the necessary `h`/`s`/`t` functions to be used in its scope.

#### component
- ex:
  - only the *last statement* in the do-block gets put into the content (has required assigns)
  - defines a macro and a function
  - useful because `@__content__` is a list of every statement inside of the macro's do-block
- js:
  - does *not* create a wrapper function, and will used the enclosing template's `h`/`s`/`t` functions

#### panel
- ex:
  - essentially all statements that
- js:
  - creates a context (cleanup unit). when the panel is destroyed, all inner event listeners are removed and cleanup functions are run.
  - (TODO) if more than 1000 units of cleanup are created, it will notify you. consider destroying your panels from time to time.

#### Condition - (Obv initialised by configuration)

these are obv's that were initialised with the values passed into the configuration. sort of like the "interface" to the external world.

#### Var - environmental variable (changes in the value are not propagated in real-time)

free-floating universal storage location. they can be used to store values. something that does not change

#### Obv (value changing over time)

this is a real-time updating value similar to its definition in the npm package [observable](https://www.npmjs.com/package/observable) -- which was later superseded by [obv](https://www.npmjs.com/package/obv).

note: this package implementation should theoretically be fully interchangeable with obv (providing additional functionality). however, if you are going to use `obv`, it must be noted that the notable difference between the two are:
- `obv` uses `null` as its undefined value, and I utilise `undefined` as the default not-yet-defined value.
- additionally, calling `obv('some value')` will always fire the listeners for [obv](https://www.npmjs.com/package/obv). in contrast, this version will only fire the listeners if the value has changed. so if you're modifying an object property or array indice of an obv's value, the listeners will not fire. (TODO: figure out if something needs to be done about this). if you need to unconditionally fire the listeners, use `obv.set(value)`.

#### bindings

obvs can be bound to each other
