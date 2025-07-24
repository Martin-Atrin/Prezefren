# Security Policy

## 🛡️ Supported Versions

We actively support security updates for the following versions of Prezefren:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | ✅ Yes             |
| < 1.0   | ❌ No              |

## 🔒 Security Features

### Privacy by Design
- **Local Processing**: Voice transcription happens entirely on your Mac
- **Optional Cloud**: Translation services only when explicitly enabled
- **No Telemetry**: Zero data collection or analytics by default
- **User Control**: Full control over data sharing and external services

### Data Handling
- **Voice Data**: Processed locally, never stored or transmitted
- **Transcriptions**: Kept in memory only, cleared on app restart
- **API Keys**: Stored locally in .env files, never transmitted to our servers
- **Network Traffic**: Only for translation when enabled, encrypted HTTPS

### Technical Security
- **Code Signing**: All releases are properly signed and notarized
- **Sandboxing**: App follows macOS security guidelines
- **Permissions**: Minimal required permissions (microphone only)
- **Dependencies**: Regularly updated third-party components

## 🚨 Reporting a Vulnerability

### Scope
We take security seriously and welcome reports for:
- **Code execution vulnerabilities**
- **Privilege escalation issues**
- **Data exposure or privacy violations**
- **Authentication bypass**
- **Input validation issues**
- **Cryptographic vulnerabilities**

### How to Report
**For security issues, please do NOT use public GitHub issues.**

#### Preferred Method: GitHub Security Advisories
1. Go to the [Security tab](https://github.com/Martin-Atrin/Prezefren/security) of our repository
2. Click "Report a vulnerability"
3. Fill out the private security advisory form
4. Include all relevant details (see template below)

#### Alternative: Private Email
If GitHub Security Advisories are not available, contact project maintainers directly through GitHub with a private message marked "SECURITY ISSUE".

### Information to Include
Please provide as much detail as possible:

```markdown
**Vulnerability Type**
- [ ] Code execution
- [ ] Privilege escalation  
- [ ] Data exposure
- [ ] Authentication bypass
- [ ] Input validation
- [ ] Cryptographic issue
- [ ] Other: ___________

**Affected Versions**
- Prezefren version(s):
- macOS version(s):
- Architecture (Intel/Apple Silicon):

**Description**
Detailed description of the vulnerability and potential impact.

**Reproduction Steps**
1. Step one
2. Step two
3. etc.

**Proof of Concept**
Include code, screenshots, or other evidence if applicable.

**Suggested Fix**
If you have ideas for how to address the issue.

**Disclosure Timeline**
Your preferred timeline for public disclosure.
```

## ⏱️ Response Timeline

### Initial Response
- **Acknowledgment**: Within 48 hours of report
- **Initial Assessment**: Within 5 business days
- **Status Updates**: Weekly until resolution

### Resolution Process
1. **Confirmation**: Verify and reproduce the issue
2. **Assessment**: Determine severity and impact
3. **Development**: Create and test fix
4. **Review**: Security review of proposed fix
5. **Release**: Coordinated disclosure and patch release
6. **Follow-up**: Monitor for additional issues

### Severity Levels

#### Critical (24-48 hours)
- Remote code execution
- Privilege escalation to admin/root
- Complete authentication bypass
- Large-scale data exposure

#### High (1 week)
- Local privilege escalation
- Significant data exposure
- Authentication bypass (limited scope)
- Cryptographic vulnerabilities

#### Medium (2-4 weeks)
- Cross-site scripting (if applicable)
- Information disclosure (limited)
- Input validation issues
- Denial of service (local)

#### Low (1-3 months)
- Minor information disclosure
- Low-impact configuration issues
- Non-security bugs with minimal impact

## 🏆 Security Researcher Recognition

### Responsible Disclosure
We believe in responsible disclosure and will work with security researchers to:
- **Coordinate timing** of public disclosure
- **Provide credit** in security advisories (if desired)
- **Share patches** for testing before public release
- **Maintain confidentiality** until patches are available

### Recognition Options
- **Security Advisory Credit**: Listed as reporter in GitHub Security Advisory
- **Release Notes**: Acknowledgment in version release notes
- **Hall of Fame**: Recognition in project documentation (coming soon)
- **No Attribution**: Anonymous reporting is fully supported

## 🔐 Security Best Practices for Users

### Installation Security
- **Download Only**: Use official releases from GitHub
- **Verify Checksums**: Check SHA256 hashes before installation
- **Code Signature**: Verify app signature with `codesign -v Prezefren.app`
- **Source Review**: Audit source code if building from source

### Runtime Security
- **Permissions**: Only grant necessary permissions (microphone)
- **API Keys**: Store translation API keys securely in .env files
- **Network**: Monitor network traffic if concerned about data
- **Updates**: Keep Prezefren updated to latest version

### Privacy Protection
- **Local Mode**: Use without translation for maximum privacy
- **API Key Security**: Rotate API keys regularly
- **Network Monitoring**: Use tools like Little Snitch if desired
- **Data Review**: Understand what data is processed locally vs cloud

## 📋 Security Measures in Development

### Code Security
- **Static Analysis**: Regular code scanning for vulnerabilities
- **Dependency Scanning**: Monitor third-party components
- **Code Review**: Security-focused review for all changes
- **Secure Coding**: Follow OWASP guidelines and Swift security best practices

### Build Security
- **Reproducible Builds**: Consistent build environment and process
- **Dependency Pinning**: Fixed versions of all dependencies
- **Code Signing**: All releases signed with valid certificates
- **Notarization**: Apple notarization for macOS releases

### Infrastructure Security
- **GitHub Security**: Repository security features enabled
- **Access Control**: Limited maintainer access with 2FA required
- **Secret Management**: No secrets in source code
- **Secure CI/CD**: Automated builds with security scanning

## 🚨 Known Security Considerations

### API Key Storage
- **Issue**: API keys stored in plaintext .env files
- **Mitigation**: Local file system permissions protect access
- **Future**: Keychain integration planned for enhanced security

### Network Traffic
- **Issue**: Translation API calls are network requests
- **Mitigation**: HTTPS encryption, no voice data transmitted
- **Alternative**: Local translation mode available (experimental)

### Microphone Access
- **Issue**: App requires microphone permission
- **Mitigation**: macOS permission system controls access
- **Transparency**: All audio processing is local

## 📞 Contact Information

### Security Team
- **GitHub**: Use Security Advisories for private reporting
- **Response Time**: 48 hours maximum for acknowledgment
- **Languages**: English preferred, community translators available

### Emergency Contact
For critical security issues requiring immediate attention:
1. Create private security advisory on GitHub
2. Mark as "Critical" severity
3. Include "URGENT" in title
4. Follow up if no response within 24 hours

## 📜 Security Policy Updates

This security policy will be reviewed and updated:
- **Quarterly**: Regular review and updates
- **Post-Incident**: After any security incidents
- **Community Feedback**: Based on researcher and user input
- **Version Changes**: When significant features are added

Last updated: January 2025
Version: 1.0

---

**Thank you for helping keep Prezefren secure!** 🙏

Your responsible disclosure helps protect all users and strengthens the security of voice transcription and translation technology.