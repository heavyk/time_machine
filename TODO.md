
### current effort

- `Logic.Assign` -> `Logic.Define` (obvs never get reassigned; they only get transformed)
- turn cond statements into multiple if-statements (eg. from top to bottom where the else is the next if)
- `input type: "number", value: ~o(num1)` needs to bind the obv to the value, eg. `el = h('input', ...); num1 = attribute(el)`
  - maybe, another function should be made: `el = bind_value(h('input', ...), obv)` this way the return is the element and the value is saved into the obv
  - or, h('input', {type: 'number', value: obv, ...}) and hyper-hermes automatically sets the value (for ~v(vars))
  - or, h('input', {type: 'number', observe: {value: obv}, ...}) (for ~o(obvs))
- get_ids does not take `Logic.Boink` into account. test to be sure this is working
  - same for `Logic.Bind1`
  - same for `Logic.Bind2`
  - same for `Logic.Transform`
  - same for `Logic.??`
  - eg. when I refer to the obv, `num` it should be defined in the inner transform / compute
    - this is kinda hairy though... I need a better way of referring to the obv being modified by the boink function
- write tests for `Boink` / `Press`
- write tests for `Bind1` / `Bind2`
- write tests for `boink: ~o(obv)` translates directly into a `Boink` without a function
  - perhaps these should translate into:
    - `h('div', {observe: {boink: obv, press: obv, value: obv, select: obv, input: obv, hover: obv, focus: obv}})`
- explore the idea that a "scope" is really a "panel" -- a unit components which can be thrown away as a whole.
  - a panel defines all of the functions necessary to make to construct the scope: h,s,t,c,v.. etc.
```js
// this is a relatively simplistic example of its basic mechanics: adding to or subtracting 1 from a number.
// this is incorrect, actually. there is confusion over whether num is an obv or a condition
// the template has it as an obv, but the return statement (and the fact that the templates are defined in the function)
// makes them conditions (global obvs).
function button_adder (G, {cod}) {
  const {h, m, v} = G
  let num = v(11)
  let tpl_cod = () => h('div', 'condition is:', cod)
  let tpl_obv = ({num}) => h('div', 'num is:', num)
  let tpl_boink = ({num}) => h('div',
    h('button', {boink: m(num, (num) => num + 1)}, 'num++'),
    h('button', {boink: m(num, (num) => num - 1)}, 'num--')
  )
  // ...
  return () => h('div',
    h('h1', 'button adder!'),
    tpl_obv({num}),
    tpl_boink({num})
  )
}
```
- make a "plugin" which creates all of the necessary bindings to the js lib. (min: h/s/t/c)
- render a simple hello world in phoenix that invokes the binding.
- make a js lib which is just an interface, where it can be hot swapped as necessary.
  - ability to load more than one lib. they are cached so the idea is to make them monstrous and containing more than enough (since it's reused by everyone, it makes no difference). this allows the "apps" to be as little as possible
- add recursion:
  - `for v <- arr do` repeats a thing for each item in a @list/~o(array)
- add idea of streams as event emitters: (implemented in js as ObservableArray event emitter)
  - events: unshift, push, pop, shift, splice, sort, replace, insert, reverse, move, swap, remove, set, empty
  - integrate this somehow with phoenix:
    - gen_server and a pubsub - where subbed events are the data...
    - presence implementation??
- make possible the ability to add custom tags: eg. `MyModule opt1: true, opt2: "lala" do ... end`
  - those call `MyModule.__marker__(opt1: true, opt2: "lala")` - which then returns some `%Marker.Element{tag: :div, content: ...}`
    - should integrate easily with the concept of `Marker.add_arg(el, arg, env)` and customised things can be done later with the element  attrs / content.
  - it could be kind of cool if `use TimeMachine.Logic` was all that was needed to make it awesome. (what is "awesome"? pfft. hell if I know, yet)
- `NameSpaceman` is a gen_server for holding scopes

### element interactions

- make `boink` and `press` fuctional
- these should all be equivalent: (the individual advantages each syntax provides are obvious)
  - `button "++", [boink: modify(~o(num), &(&1 + 1))]`
  - `button "++", [boink: modify(~o(num), fn num -> num + 1 end)]`
  - `button "++", [boink: fn ~o(num) -> num + 1 end]`
  - `button "++", [boink: ~o(num) <- num + 1]`
- event listeners available are:
  - modify(obv, fun) -> an event listener, which calls fun with: (obv value, event), then sets obv equal to the return value
  - boink(obv, modifier = (v) => !v) -> an event listener, which flips the value of obv every event (default for boink)
  - press(obv, pressed = true, normal = false) -> an event listener which sets obv to value when called (default for press)
  ...

### first steps

- integrate into phoenix a simple html page, then compiles the template into js
- make a toggle if-else button that switches text render in phoenix (and works)

### poem???

- I have often thought about this idea of a `poem` as the framework for building things...
- as I continue, I am beginning to see that it may make more sense to separate things into environments
  - the totality of the "thing" is the "universe" where all pure templates are stored and conditions are defined
  - panel is a visual section of the "thing" - where a sub environment is made, and if any impure templates

### async scopes

- use generators / promises to allow for things to happen asynchronously

### optimiser

- make a gen_server which stores information about the ast (like variable name and scope)
- and can do things like rename variables and stuff

### js implementation

- assume the `t`/`c` function is an alias to `obv.transform` / `obv.compute`
- panel gets the scope and creates the `h`/`s` function. any observables listened to need to be unlistened when the scope is cleaned.

### general

- convert to an umbrella project (https://github.com/JakeBecker/elixir-ls)
- when use TimeMachine.Compiler is invoked, add a hook to parse the `@css` module attributes.
  - see `TimeMachine.Templates` -- https://gist.github.com/mprymek/8379066
  - also, https://elixir-lang.org/getting-started/meta/domain-specific-languages.html
- create mapping from templates into roadtrip configuration
  -> templates are kinda like 'pages' and components are different things inside the templates
- create a hook when compiling the module to also compile the module's css
- ~j/var js_var = 1; console.log('jsvar:', js_var)/ will get inlined into the resulting function
- store variable names as atoms instead of binaries
- instead kw lists, use a map! - https://elixir-lang.org/getting-started/keywords-and-maps.html
- improve errors
  - ErrorInternalBadness - boilerplate misunderstanding of elixir to js conversion
  - ErrorIncompatibleAwesomeness - stuff like ~o(lala) and ~v(lala) cannot coexist in the same template

### smallish things

- add opts to the compiler and store some basic state in it (like parent node and stuff)
- since ~O(env_obv) / ~o(local_obv) --> ~V(env_var) / ~v(local_var)
  - however, I cannot really think of a good reason why local vars would be desired (and for now, it will just create unnecessary complexity)

### cool ideas

- module connections: eg. `(MyModule awesome: true, wicked: true) <~> (YourModule sexy: true, alive: true)`
  - <~>, <~, ~>
  - defmacro my_cool_tag() do
      (MyModule awesome: true, wicked: true) <~> (YourModule sexy: true, alive: true)
    end


### errors

I really want to make the errors show up in phoenix in such a way where it will show the error, the relevant code, suggestions and other things. I also want to begin moving the interface away from a line based view of the error, and into more of a code block sort of view... like blocks of ast (and potential transformations that can be done on them to fix the error)

### ideas to streamline future adoption

- (maybe) convert the Eml html parser to make ractive-like "panel" files where there is: html,css,script sections.
  - this will allow a bridge for js-oriented person to be able to start integrating those ractive-like panels.
  - then, once familiar with that, it may be easier to ease into the elixir side of things as an obvious improvement.
  - this should be held off as long as possible though, to encourage the use of metaprogramming in elixir to reach new heights of complexity -- eg. a gmail clone should appear relatively easy.
- TODO MVC demo

------------------------

[ 00:00:00 ] | [combo]
  [snooze]   | [list]
 [settings]  | -------

combo should emulate the gmail new label combobox (with the new text field n'stuff)

for settings, add ability to edit sounds as well as the pomodoro settings

```js
({num}) => [
  transform(num, (v) => v ? h('div', 'yay') : h('div', 'nope')),
  h('div', transform(num, (v) => !v ? 'yay' : 'nope'))
]
```

### notes

- debug: https://onor.io/2016/02/17/quick-elixir-debugging-tip/
- const stuff: https://github.com/jcomellas/ex_const
