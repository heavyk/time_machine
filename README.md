# TimeMachine

An implementation of a pomodoro timer in elixir, which renders to js

the intent is to show how the interface can be made entirely in elixir, then
regular js can listen for the events from the interface and do stuff, but the
interface should be easily renderable by phoenix and operate properly without
any of the bindings.

## Implementation notes

assigns that end with a `!` (eg. `@variable!`), will become a js observable.


#### fragment
- ex:
  - every statement in the do-block gets put into the content (has optional assigns)
  - defines a function
- js:
  - ???

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
