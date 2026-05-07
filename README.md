# ETS2 Scroll Drive

Mouse steering and scroll-wheel throttle/brake controls for Euro Truck Simulator 2.

## Files

- `controls.sii`: ETS2 controls profile.
- `start_ets2_scroll_overlay.cmd`: optional overlay that shows the current throttle or brake percentage.

## Controls

- Move mouse: steer.
- Scroll up: increase throttle.
- Scroll down: increase brake.
- Right mouse + scroll: camera zoom.
- `Alt + middle mouse`: reset throttle/brake to neutral.
- `Ctrl + Alt + Q`: close the overlay.

## Behavior

The scroll wheel value is stored by ETS2, not by the overlay. The overlay is only a display.

Each wheel step changes the stored value by 5%, from full brake to full throttle. ETS2 applies a squared curve, so small scroll changes are gentle and full scroll range still reaches 100%.

If the overlay display and the in-game input ever disagree, press `Alt + middle mouse` to reset both to neutral.

Do not edit controls that show as `complex` in ETS2's buttons menu. Those are custom bindings from `controls.sii`, and changing them in-game can break the scroll controls.

## Transmission Notes

The mod does not depend on the truck's gearbox model or number of gears.

- Automatic and sequential transmissions are the best fit.
- In simple automatic, scroll down uses ETS2's normal backward input. At a stop, holding brake may engage reverse.
- Real automatic users may need to bind Drive and Reverse separately in ETS2.
- H-shifter/manual users should merge the scroll steering/throttle/brake bindings into their own controls profile instead of replacing it.

## License

MIT License. See `LICENSE`.
