#!/bin/bash

# Function to install agent-guides in a project
install_agent_guides() {
    # Check if a path argument was provided
    if [ $# -eq 0 ]; then
        echo "Error: Please provide a project path"
        echo "Usage: install_agent_guides /path/to/your/project"
        return 1
    fi
    
    local PROJECT_PATH="$1"
    local TEMP_DIR="/tmp/agent-guides-$$"
    
    # Validate the project path exists
    if [ ! -d "$PROJECT_PATH" ]; then
        echo "Error: Project directory '$PROJECT_PATH' does not exist"
        return 1
    fi
    
    echo "Installing agent-guides to: $PROJECT_PATH"
    
    # Clone the repository to a temporary directory
    echo "Cloning agent-guides repository..."
    if ! git clone https://github.com/tokenbender/agent-guides "$TEMP_DIR" 2>/dev/null; then
        echo "Error: Failed to clone repository"
        return 1
    fi
    
    # Create the .claude directory structure
    mkdir -p "$PROJECT_PATH/.claude/commands"
    mkdir -p "$PROJECT_PATH/.claude/scripts"
    
    # Copy claude commands
    if [ -d "$TEMP_DIR/claude-commands" ]; then
        echo "Installing Claude commands..."
        cp -r "$TEMP_DIR/claude-commands/"* "$PROJECT_PATH/.claude/commands/" 2>/dev/null || {
            echo "Warning: No claude-commands found to copy"
        }
    fi
    
    # Copy supporting scripts
    if [ -d "$TEMP_DIR/scripts" ]; then
        echo "Installing supporting scripts..."
        cp -r "$TEMP_DIR/scripts/"* "$PROJECT_PATH/.claude/scripts/" 2>/dev/null || {
            echo "Warning: No scripts found to copy"
        }
    fi
    
    # Clean up temporary directory
    rm -rf "$TEMP_DIR"
    
    echo "✅ Agent guides installed successfully!"
    echo "Files installed to:"
    echo "  - $PROJECT_PATH/.claude/commands/"
    echo "  - $PROJECT_PATH/.claude/scripts/"
}

# For convenience, also create an alias
alias iag='install_agent_guides'