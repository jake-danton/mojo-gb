# [WIP] Mojo Gameboy Emulator

This project was created to explore the Mojo programming language and basic emulation. All the emulator logic is written in pure Mojo with basic display and input handling implemented through `pygame`.

## Current Status

This emulator is far enough along to play simple games like *Tetris*. And that's about it.

The plan is to slowly continue working on it, to hopefully get more functionality to work, but more importantly, to improve the Mojo metaprogramming aspects. So, for example, I am far less interested in getting audio working than improving the structure and logic of the CPU instructions as I continue to learn more about Mojo and as Mojo adds more metaprogramming features.

The ideal goal: convert the game ROM into Mojo code at compile time 🔥

### TODOs

- [x] CPU Instructions
- [x] Memory Bus
- [x] Basic GPU
- [x] Graphics Display
- [x] Keyboard Input
- [x] Reasonable unit test coverage
- [ ] Some potential half carry flag bugs
- [ ] `0x8800` addressing mode (required for even basic games like *Tennis*)
- [ ] MBC Support (required for larger games like *Metroid II*)
- [ ] Audio

## How to run it

You will need to provide your own ROMs.

```
magic run mojo run ./main.mojo <Boot ROM file> <Game ROM File> [<Pixel Scale Factor>]
```

## Prerequisites

### Install Magic

```
curl -ssL https://magic.modular.com | bash
```

See [Get started with Mojo](https://docs.modular.com/mojo/manual/get-started/) for more information.