# Shell Scripting

This folder contains simple Bash scripts for learning the basic parts of shell scripting.

## How to run a script

Open a Linux terminal or Git Bash in this folder and run:

```bash
bash file-name.sh
```

For example:

```bash
bash hello.sh
```

## Scripts

### 1. Hello and files - `hello.sh`

This script creates a folder called `hello`, moves into it, and creates a file called `app.log`. It writes text into the file and displays the text with `cat`.

The script writes a second message using `>`, so the old message is replaced. The commented lines at the top show an earlier manual version of the same work.

### 2. Variables - `variable.sh`

This script stores a name, roll number, and comment in variables. It then prints those values using `$name`, `$rollNo`, and `$comment`.

### 3. User input - `input.sh`

This script asks the user for a name, roll number, and comment. The answers are saved in variables and printed on the screen. The `read` command is used to receive input.

### 4. Conditions - `condition.sh`

This script asks for the user's age and uses `if`, `elif`, and `else` to print a message. It checks whether the person is a child, teenager, adult, or has entered an invalid/very large age.

### 5. `for` loop - `loop.sh`

This script uses a `for` loop to count from 1 to 5. It prints the current iteration number each time.

### 6. `while` loop with input - `while_loop.sh`

This script keeps asking the user to enter a number. It stops when the user enters `q`. Invalid values show an error message, while valid numbers are printed. `break` stops the loop and `continue` moves to the next loop cycle.

### 7. `while` loop with a counter - `while_loop2.sh`

This script starts a counter at 0 and prints numbers while the counter is less than 5. The counter is increased with `((count++))` after every cycle.

### 8. Function - `function.sh`

This script defines a function named `show_info`. The function contains two messages and is intended to display them when called.

The last line currently contains `show_info()` without a function body, which causes a Bash syntax error. To run the function, the last line should be:

```bash
show_info
```

### 9. Combined system information - `script.sh`

This script combines several ideas:

- Creates the `result_file` folder.
- Creates `result.log` and writes information into it.
- Displays the date, disk space, and running processes.
- Creates `process.log` using the `ps` command.
- Asks the user for a name and roll number.
- Adds the name and current date to `result.log` using `>>`.

Note: `echo $hostname` and `echo $whoami` try to print variables named `hostname` and `whoami`. They may print blank values. The commands normally used for this information are `hostname` and `whoami`.

## Useful Bash symbols used here

- `>` writes to a file and replaces its old content.
- `>>` adds text to the end of a file.
- `$variable` gets the value stored in a variable.
- `read` gets input from the user.
- `if`, `elif`, and `else` make decisions.
- `for` and `while` repeat commands.
- `break` exits a loop.
- `continue` skips to the next loop cycle.
