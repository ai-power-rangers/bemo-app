
Use error tracking dependency from game host or delegate or depdnecy container or where it makes sense

Definitive Tangram Editor UX:

User clicks Tangram Editor

User Selects an existing Puzzle to edit or creates new

User places first block and has ability to rotate or flip (before confirming), and can confirm or cancel.

Once placed, a piece is locked by default but a user can select it to delete it, unlock it. If unlocked, as long as it doesn’t violate Tangram rules, it can be rotated, flipped, etc. 

All other actions (like select/deselect of other pieces are blocked/hidden and there is an indicator of current status. Only options that make sense per status are shown or provided. Only valid manipulations or connections are allowed. Improper selections/invalid selections/etc show toast errors instead of failing silently.

Valid Rules
-All pieces must be connected by at least one point (vertex to vertex, vertex to edge, edge to edge)
-Edges of different sizes are allowed

Statuses:
Select first shape: only option is selecting a shape from the bottom bar

Manipulate first shape: Rotate/flip (if one shape)

Select connections (1 min, 2 max; must be valid, like two edges on opposite sides is not valid)

Select next shape: only option is selecting a shape from the bottom bar

Select next shape connections: only show valid connection points as options (show an opaque preview of where it would be place based on these connections; have the ability to select/deslect)

Manipulate pending shape: Rotate/flip (if one shape), Rotate around vertex (if the shape being manipulated is just connected to another shape on one of its vertices), Slide (if the shape being manipulated is just connected to another by edge); Note if there are two connection points, there is no manipulations possible. Only valid manipulations are possible.

Select next shape (and repeat)

Other:
- Undo/redo

