# TimeMachine

An implementation of a pomodoro timer in elixir, which renders to js

the intent is to show how the interface can be made entirely in elixir, then
regular js can listen for the events from the interface and do stuff, but the
interface should be easily renderable by phoenix and operate properly without
any of the bindings.

## Implementation notes

assigns with a `!` at the end eg. `@variable!`, will become a js observable.


#### fragment
- every statement in the do-block gets put into the content (has optional assigns)
- creates a function

#### template
- only the *last statement* in the do-block gets put into the content (has optional assigns)
- creates a function

#### component
- only the *last statement* in the do-block gets put into the content (has required assigns)
- creates a macro and a function
- useful because `@__content__` is a list of every statement inside of the macro's do-block
