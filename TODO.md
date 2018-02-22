
### first steps

- integrate into phoenix a simple html page, then compiles the template into js
- make a toggle if-else button that switches text render in phoenix (and works)

### js implementation
- panel gets the scope and creates the `h`/`s` function. any observables listened to need to be unlistened when the scope is cleaned.

### general

- convert to an umbrella project (https://github.com/JakeBecker/elixir-ls)
- when use TimeMachine.Compiler is invoked, add a hook to parse the `@css` module attributes.
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

------------------------

[ 00:00:00 ] | [combo]
  [snooze]   | [list]
 [settings]  | -------

combo should emulate the gmail new label combobox (with the new text field n'stuff)

for settings, add ability to edit sounds as well as the pomodoro settings

```js
({num}) => [
  transform(this.num, (v) => v == 2 ? h('div', 'yay') : h('div', 'nope')),
  h('div', transform(this.num, (v) => v == 2 ? 'yay' : 'nope'))
]
```
