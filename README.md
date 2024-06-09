# loq

The loq ~~Programming Language~~ Math Interpreter. 

## About

`loq` is an "advanced math interpreter" meaning `loq` allows for custom function definitions, recursion and more all in a mathmatical format.

## Features

Currently, `loq` only supports integers although floating point values are in the development plan.

### Roadmap

#### Done ✓

- [x] Mathmatical Expressions
- [x] Logical Expressions
- [x] Variables
- [x] Functions
- [x] Multiple Parameters
- [x] Recurssion 
- [x] Output (print statement)
- [x] Ternary Operator (Conditionals)

#### In Progress

- [ ] Binary Mathmatical Expressions
- [ ] Module Imports
- [ ] User Input

#### Todo

- [ ] Constants
- [ ] Strings Values
- [ ] Array/Matrix Values
- [ ] Loops Values
- [ ] Floating Point Numbers

### Performance

Especially in recursion benchmarks, `loq` performs 24x worse than slow languages such as Ruby. 

### Syntax

The following function written in C finds the Greatest Common Denominator of the values `x` and `y` using recurssion.

```c
int gcd(int x, int y) {
    if (y == 0) {
        return x;
    } else {
        return gcd(y, (x % y));
    }
}
```

In `loq`, You can represent the above code segment like the following...

```
gcd(x, y) = (y == 0) ? x : gcd(y, (x % y));
```

## Building

`loq` requires a couple of dependencies in order to be built. These dependencies are...

```
flex
bison
clang
make
```

Once these dependencies have been installed, go to the root directory of the project and run the `make` command.

Although we recommend clang, any mainstream C/C++ compiler should still work.

### Linux

#### Debian

```bash
# Install dependencies
sudo apt-get update -y
sudo apt-get install flex bison clang make -y
# Building the project
make
```

#### Arch

```bash
# Install dependencies
sudo pacman -Syu
sudo pacman -Sy flex bison clang make
# Building the project
make
```

### macOS

#### With XCode

If you already have XCode Build Tools already installed, all of the packages needed to compile this project should be already installed.

```bash
# You do not need to install any dependencies as XCode should have already installed them.
# Building the project
make
```

If the build still fails, follow the [Without XCode](#without-xcode) section below. After that, if the build still fails please don't hesitate to create an issue on GitHub.

#### Without XCode

If you do not have XCode Build Tools installed, you can install the required packages using the following commands.

```bash
# Install dependencies
brew update
brew install llvm@16 bison make
# Building the project
make
```