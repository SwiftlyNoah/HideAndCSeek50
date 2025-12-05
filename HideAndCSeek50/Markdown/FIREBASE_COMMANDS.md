# Firebase Functions - Command Reference

Quick reference for deploying and managing your Cloud Functions.

## 📦 Initial Setup

```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Check Firebase CLI version
firebase --version

# Login to Firebase
firebase login

# Initialize Firebase in your project (one-time setup)
firebase init functions
# Select: 
# - Your Firebase project
# - JavaScript
# - ESLint: Yes
# - Install dependencies: Yes
```

## 🚀 Deployment Commands

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy a specific function
firebase deploy --only functions:sendChatNotification

# Deploy with force (skip ESLint errors - use cautiously)
firebase deploy --only functions --force

# View deployment status
firebase projects:list
```

## 📊 Monitoring Commands

```bash
# View logs in real-time
firebase functions:log

# View logs for specific function
firebase functions:log --only sendChatNotification

# View logs with limit
firebase functions:log --limit 50

# View logs since a specific time
firebase functions:log --since 2h  # Last 2 hours
firebase functions:log --since 30m # Last 30 minutes
firebase functions:log --since 1d  # Last day
```

## 🧪 Testing Commands

```bash
# Start Firebase emulators (local testing)
firebase emulators:start

# Start only functions emulator
firebase emulators:start --only functions

# Test functions locally with Firebase shell
firebase functions:shell
```

## 🔧 Maintenance Commands

```bash
# Install/update dependencies
cd functions
npm install

# Update Firebase packages
npm update firebase-admin firebase-functions

# Check for outdated packages
npm outdated

# Audit for security vulnerabilities
npm audit
npm audit fix
```

## 🗑️ Cleanup Commands

```bash
# Delete a specific function
firebase functions:delete sendChatNotification

# Delete multiple functions
firebase functions:delete function1 function2

# List all deployed functions
firebase functions:list
```

## 📝 ESLint Commands

```bash
# Navigate to functions directory
cd functions

# Run ESLint
npm run lint

# Auto-fix ESLint issues
npm run lint -- --fix

# Check specific file
npx eslint index.js
```

## 🔍 Debug Commands

```bash
# Check which Firebase project you're using
firebase use

# Switch Firebase project
firebase use project-name

# List available projects
firebase projects:list

# Check Firebase config
firebase functions:config:get
```

## 📂 Project Structure Commands

```bash
# View functions directory structure
cd functions
ls -la

# View package.json
cat package.json

# View installed packages
npm list --depth=0
```

## ⚙️ Configuration Commands

```bash
# Set environment variable
firebase functions:config:set someservice.key="THE API KEY"

# Get environment variables
firebase functions:config:get

# Clone config from one project to another
firebase functions:config:clone --from=prod-project --to=dev-project
```

## 🎯 Common Workflows

### First-time Deployment

```bash
# 1. Navigate to your project
cd /path/to/HideAndCSeek50

# 2. Login to Firebase
firebase login

# 3. Initialize (if not done)
firebase init functions

# 4. Go to functions folder
cd functions

# 5. Install dependencies
npm install

# 6. Go back to project root
cd ..

# 7. Deploy
firebase deploy --only functions
```

### Update Existing Functions

```bash
# 1. Edit functions/index.js
# (make your changes)

# 2. Go to functions folder
cd functions

# 3. Run linter
npm run lint

# 4. Fix any issues
npm run lint -- --fix

# 5. Go back to root
cd ..

# 6. Deploy
firebase deploy --only functions
```

### View Logs After Update

```bash
# Deploy and immediately start watching logs
firebase deploy --only functions && firebase functions:log
```

### Quick Test

```bash
# 1. Send a test chat message in your app
# 2. Check logs immediately
firebase functions:log --only sendChatNotification --since 1m
```

## 🚨 Troubleshooting Commands

### Function Not Working

```bash
# Check recent logs
firebase functions:log --only sendChatNotification --limit 20

# Check function exists
firebase functions:list

# Check Firebase config
firebase use
```

### Deployment Issues

```bash
# Clear cache and redeploy
cd functions
rm -rf node_modules package-lock.json
npm install
cd ..
firebase deploy --only functions
```

### Node Version Issues

```bash
# Check Node.js version
node --version

# Update Node.js (use nvm)
nvm install 18
nvm use 18

# Verify again
node --version
```

## 📊 Performance Monitoring

```bash
# View function metrics in browser
firebase console:functions

# This opens Firebase Console in your browser
# Navigate to: Functions → select function → Usage tab
```

## 🔐 Security Commands

```bash
# Test database rules
firebase database:get / --shallow

# Update database rules
firebase deploy --only database

# View current project
firebase projects:list
```

## 📦 Package Management

```bash
# Check for security vulnerabilities
npm audit

# Fix vulnerabilities
npm audit fix

# Force fix (may introduce breaking changes)
npm audit fix --force

# Update specific package
npm update firebase-admin
```

## 🎓 Learning Commands

```bash
# Get help
firebase --help
firebase functions:log --help
firebase deploy --help

# View Firebase documentation
firebase open docs
```

## ⚡ Quick Reference Table

| Command | Description |
|---------|-------------|
| `firebase deploy --only functions` | Deploy all functions |
| `firebase functions:log` | View logs in real-time |
| `firebase functions:log --since 1h` | View last hour of logs |
| `firebase functions:list` | List deployed functions |
| `npm run lint` | Check code style |
| `npm run lint -- --fix` | Auto-fix code style |
| `firebase use` | Check current project |
| `firebase login` | Login to Firebase |
| `firebase init functions` | Initialize functions |

## 💡 Pro Tips

1. **Always run linter before deploying**
   ```bash
   cd functions && npm run lint && cd .. && firebase deploy --only functions
   ```

2. **Monitor logs during first deployment**
   ```bash
   # Terminal 1
   firebase deploy --only functions
   
   # Terminal 2
   firebase functions:log
   ```

3. **Keep a backup of working code**
   ```bash
   cp functions/index.js functions/index.js.backup
   ```

4. **Test locally before deploying**
   ```bash
   firebase emulators:start --only functions
   ```

5. **Check costs regularly**
   - Visit Firebase Console → Usage and billing
   - Set up billing alerts

## 📞 Additional Resources

- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Node.js Installation](https://nodejs.org/)
- [Firebase Console](https://console.firebase.google.com)
