PREFIX ?= /usr/local

.PHONY: install uninstall install-user app

# Build + install the menu bar app and the CLI
app:
	@./build.sh


install:
	@echo "Installing multibb to $(PREFIX)/bin..."
	@mkdir -p $(PREFIX)/bin
	@cp multibb $(PREFIX)/bin/multibb
	@chmod +x $(PREFIX)/bin/multibb
	@echo "Done! Run 'multibb init' to get started."

uninstall:
	@echo "Removing multibb from $(PREFIX)/bin..."
	@rm -f $(PREFIX)/bin/multibb
	@echo "Done!"
	@echo "Note: Your profiles in ~/Library/Application Support/ were not removed."

install-user:
	@echo "Installing multibb to ~/bin..."
	@mkdir -p ~/bin
	@cp multibb ~/bin/multibb
	@chmod +x ~/bin/multibb
	@echo "Done!"
	@echo ""
	@echo "Make sure ~/bin is in your PATH. Add this to ~/.zshrc:"
	@echo '  export PATH="$$HOME/bin:$$PATH"'
	@echo ""
	@echo "Then run 'multibb init' to get started."
