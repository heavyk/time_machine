
### current effort

- explore the idea that a "scope" is really a "panel" -- a unit components which can be thrown away as a whole.
  - a panel defines all of the functions necessary to make to construct the scope: h,s,t,c,.. etc.
- make a "plugin" which creates all of the necessary bindings to the js lib.
- make a js lib which is just an interface, where it can be hot swapped as necessary.
  - ability to load more than one lib. they are cached so the idea is to make them monstrous and containing more than enough (since it's reused by everyone, it makes no difference). this allows the "apps" to be as little as possible
- make possible the ability to add custom tags: eg. `MyModule opt1: true, opt2: "lala" do ... end`
  - those call `MyModule.__marker__(opt1: true, opt2: "lala")` - which then returns some `%Marker.Element{tag: :div, content: ...}`

### first steps

- integrate into phoenix a simple html page, then compiles the template into js
- make a toggle if-else button that switches text render in phoenix (and works)

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
- TimeMachine.Compiler is just a shell which returns the element.
  -> instead return js and stuff (this requires the use of {:safe, str} to ensure things aren't double escaped)
- create mapping from templates into roadtrip configuration
  -> templates are kinda like 'pages' and components are different things inside the templates
- top-level templates/fragments get converted to functions with (assigns/d) and `@value` expands to assigns.value
  -> but, maybe I want to do the assigns in the "this" context of the function (actually no, to follow the observable model)
- add conditional expressions which work with observables, such as if-else and cond (but case will need extra thought - I don't think it's easy)
- create a hook when compiling the module to also compile the module's css
- ~j/var js_var = 1; console.log('jsvar:', js_var)/ will get inlined into the resulting function

### smallish things

- add opts to the compiler and store some basic state in it (like parent node and stuff)

### cool ideas

- module connections: eg. `(MyModule awesome: true, wicked: true) <~> (YourModule sexy: true, alive: true)`
  - <~>, <~, ~>
  - defmacro my_cool_tag() do
      (MyModule awesome: true, wicked: true) <~> (YourModule sexy: true, alive: true)
    end


### ideas to streamline future adoption

- (maybe) convert the Eml html parser to make ractive-like "panel" files where there is: html,css,script sections.
  - this will allow a bridge for js-oriented person to be able to start integrating those ractive-like panels.
  - then, once familiar with that, it may be easier to ease into the elixir side of things as an obvious improvement.
  - this should be held off as long as possible though, to encourage the use of metaprogramming in elixir to reach new heights of complexity -- eg. a gmail clone should appear relatively easy.

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
