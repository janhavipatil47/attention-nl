# Firebase Functions Setup (Gmail SMTP)

1. Install Firebase CLI and login:
   - `npm i -g firebase-tools`
   - `firebase login`

2. Set your Firebase project:
   - `firebase use <your-project-id>`

3. Install dependencies:
   - `cd functions`
   - `npm install`

4. Set Gmail credentials as Firebase secrets:
   - `firebase functions:secrets:set GMAIL_SMTP_USER`
   - `firebase functions:secrets:set GMAIL_SMTP_PASS`

5. Deploy functions:
   - `npm run deploy`

How it works:
- A new Firestore document in `assessment_reports` triggers `sendAssessmentReportEmail`.
- Function creates a PDF summary and emails parent via Gmail SMTP.
- Email status is written back in `assessment_reports/{reportId}.email.status`.
