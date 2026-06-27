# Focus Quest Example

This example demonstrates the public API of the focus_quest package.

It shows how to:

- initialize the controller
- start and stop focus sessions
- inspect progress and streak state
- use lifecycle handling for background transitions
- persist sessions locally with SharedPreferences
- attach metadata that an app can turn into virtual garden, pet, or charity progress

The example intentionally keeps the game layer simple. Real anti-doomscroll apps
can use the package state to build shareable progress screens, pets, gardens, or
impact dashboards without moving business logic into the UI.
