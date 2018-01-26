
### first steps

- integrate into phoenix a simple html page, then compiles the template into js
- make a toggle if-else button that switches text render in phoenix (and works)

### general

- convert to an umbrella project (https://github.com/JakeBecker/elixir-ls)
- when use TimeMachine.Compiler is invoked, add a hook to parse the `@css` module attributes.
- TimeMachine.Compiler is just a shell which returns the element.
  -> instead return js and stuff
- create mapping from templates into roadtrip configuration
  -> templates are kinda like 'pages' and components are different things inside the templates
- top-level templates/fragments get converted to functions with (assigns/d) and `@value` expands to assigns.value
  -> but, maybe I want to do the assigns in the "this" context of the function
- add conditional expressions which work with observables, such as if-else
- create a hook when compiling the different modules to compile the module's css
- ~j/var js_var = 1; console.log('jsvar:', js_var)/ will get inlined into the resulting function

### smallish things

- add opts to the compiler and store some basic state in it (like parent node and stuff)

------------------------

[ 00:00:00 ] | [combo]
  [snooze]   | [list]
 [settings]  | -------

combo should emulate the gmail new label combobox (with the new text field n'stuff)

for settings, add ability to edit sounds as well as the pomodoro settings
