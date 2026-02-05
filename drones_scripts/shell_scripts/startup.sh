#!/bin/bash

# Configuration
SESSION_NAME="api"
PYTHON_SCRIPT="python_scripts/utils/startup.py"  # Replace with your script name
VENV_PATH="./.env/bin/activate" # Optional: path to your virtual env

# 1. Check if the session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
  # 2. Create a new session, but don't attach to it yet (-d)
  tmux new-session -d -s $SESSION_NAME

  # 3. Optional: Source a virtual environment
  tmux send-keys -t $SESSION_NAME "source $VENV_PATH" C-m

  # 4. Send the command to run your Python program
  # C-m is the equivalent of pressing 'Enter'
  tmux send-keys -t $SESSION_NAME "python3 $PYTHON_SCRIPT" C-m

  echo "Session '$SESSION_NAME' started and script is running."
else
  echo "Session '$SESSION_NAME' is already running."
fi

# 5. Attach if you want to see it, otherwise the script ends here and it stays detached
echo "Use 'tmux attach -t $SESSION_NAME' to view the process."
