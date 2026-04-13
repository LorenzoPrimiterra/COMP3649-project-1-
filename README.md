# COMP 3649 Programming Project

## Overview:
This is a basic compiler for a simple target architecture that utilizes basic arithmetic and move operations,<br> e.g. (ADD, SUB, MUL, DIV, MOV ( src ,  R<sub>i</sub> ), and MOV(R<sub>i</sub>, dst)).<br> This project is implemented in both python and haskell. More information may be available in each implementation's respective README file or other supporting documentation.

## Building:
The haskell version of this project runs on GHCi. Any terminal or IDE that can run GHCi should be able to run the project, with `stack build` and `pip install -r requirements.txt` being used to install all dependencies and requirements for the project.

## Executing:

To execute the program, the syntax expected is<br> `python main.py <NUM_REGISTERS> <INPUT_FILENAME>`. For Haskell, you need to run the following in your terminal: 
```
ghc -o gen Main.hs
./gen 3 test.txt
```

### Executing Test Cases:

#### Automated Testing:

To run any automated tests, type in ` pytest ` or ` stack test `. 

#### Manual Testing:
Use the command from above, but on any valid text file. E.G. `python main.py 3 test.txt` or `./gen 3 test.txt`


# Information:

## Limitations:

This project is currently unable to perform any form of register spilling. This means that without enough registers, compilation will fail because the compiler backend will be unable to allocate enough registers.
## Detailed Information:
More detailed information on each stage of the project is available in the respective python and haskell folders, under the following names: `/Project 1/README.md` <br>and `/Haskell-Solution/src/README.md`. Text versions are available in `extra` folder.