# Google Apps Script Email Setup (No Blaze)

This setup sends the assessment report email through your Gmail account without Firebase Functions.

## 1) Create Apps Script Web App

1. Open https://script.google.com
2. Create a new project.
3. Replace code with the script below.
4. Deploy -> New deployment -> Web app.
5. Execute as: `Me`
6. Who has access: `Anyone`
7. Deploy and copy the `/exec` URL.

```javascript
function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents || '{}');

    var parentEmail = data.parentEmail || '';
    if (!parentEmail) {
      return ContentService
        .createTextOutput(JSON.stringify({ ok: false, error: 'Missing parentEmail' }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    var childName = data.childName || 'Child';
    var parentName = data.parentName || 'Parent';
    var parentEmail = data.parentEmail || '';
    var childAge = data.childAge || '-';
    var childGrade = data.childGrade || '-';
    var assessmentType = data.assessmentType || '-';
    var generatedAt = data.createdAtIso || new Date().toISOString();
    var scores = data.scores || {};
    var skillLabels = data.skillLabels || {};
    var skillKeys = data.scoredSkillKeys || [];
    var insights = data.insights || [];
    var recommendations = data.recommendations || [];
    var activities = data.assessedActivities || [];
    var parentQuestionnaire = data.parentQuestionnaire || {};

    var doc = DocumentApp.create('NeuroLearn Report - ' + childName + ' - ' + new Date().getTime());
    var body = doc.getBody();

    body.appendParagraph('NeuroLearn Assessment Report')
      .setHeading(DocumentApp.ParagraphHeading.HEADING1);
    body.appendParagraph('Status: ' + (data.statusLabel || 'Assessment Complete'));
    body.appendParagraph('Generated At: ' + generatedAt);
    body.appendParagraph('');

    body.appendParagraph('Profile Details')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    body.appendParagraph('Child Name: ' + childName);
    body.appendParagraph('Child Age: ' + childAge);
    body.appendParagraph('Child Grade: ' + childGrade);
    body.appendParagraph('Parent Name: ' + parentName);
    body.appendParagraph('Parent Email: ' + parentEmail);
    body.appendParagraph('Assessment Type: ' + assessmentType);
    body.appendParagraph('');

    body.appendParagraph('Score Summary')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    body.appendParagraph('Overall: ' + Math.round(scores.overall || 0) + '%');
    body.appendParagraph('Confidence: ' + Math.round(scores.confidence || 0) + '%');
    body.appendParagraph('');

    body.appendParagraph('Assessed Skills')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    for (var k = 0; k < skillKeys.length; k++) {
      var key = skillKeys[k];
      if (key === 'overall' || key === 'confidence' || key === 'dataCoverage') continue;
      var label = skillLabels[key] || key;
      var value = Math.round(scores[key] || 0);
      body.appendParagraph(label + ': ' + value + '%');
    }
    body.appendParagraph('');

    body.appendParagraph('Key Insights')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    if (insights.length === 0) {
      body.appendParagraph('- No insights generated.');
    } else {
      for (var i = 0; i < insights.length; i++) {
        body.appendParagraph('- ' + insights[i]);
      }
    }
    body.appendParagraph('');

    body.appendParagraph('Parent Questionnaire Contribution')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    if (parentQuestionnaire.available) {
      body.appendParagraph('Responses Considered: ' + (parentQuestionnaire.answeredQuestions || 0));
      body.appendParagraph('Parent Reported Risk: ' + Math.round(parentQuestionnaire.overallRisk || 0) + '%');
    } else {
      body.appendParagraph('Parent questionnaire not available for this report.');
    }
    body.appendParagraph('');

    body.appendParagraph('Recommendations')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    if (recommendations.length === 0) {
      body.appendParagraph('- No recommendations generated.');
    } else {
      for (var j = 0; j < recommendations.length; j++) {
        body.appendParagraph('- ' + recommendations[j]);
      }
    }
    body.appendParagraph('');

    body.appendParagraph('Activities Included In Assessment')
      .setHeading(DocumentApp.ParagraphHeading.HEADING2);
    if (activities.length === 0) {
      body.appendParagraph('- No activities listed.');
    } else {
      for (var a = 0; a < activities.length; a++) {
        body.appendParagraph('- ' + activities[a]);
      }
    }

    doc.saveAndClose();

    var pdfBlob = DriveApp.getFileById(doc.getId())
      .getAs(MimeType.PDF)
      .setName(childName.replace(/\s+/g, '_') + '_assessment_report.pdf');

    MailApp.sendEmail({
      to: parentEmail,
      subject: 'Assessment Report for ' + childName,
      htmlBody: 'Hello,<br><br>Please find attached the latest NeuroLearn assessment report.<br><br>Regards,<br>NeuroLearn Team',
      attachments: [pdfBlob]
    });

    DriveApp.getFileById(doc.getId()).setTrashed(true);

    return ContentService
      .createTextOutput(JSON.stringify({ ok: true, message: 'Email sent' }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ ok: false, error: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
```

## 2) Configure URL in Flutter

Run app with webhook URL:

```powershell
flutter run -d chrome --dart-define=APPS_SCRIPT_WEBHOOK_URL="https://script.google.com/macros/s/REPLACE_WITH_YOURS/exec"
```

Or store it once at runtime by calling `EmailWebhookService.setWebhookUrl(...)` from your app.

## 3) Test

1. Complete an assessment.
2. Check Firestore `assessment_reports` document:
   - `email.status` should become `sent`.
3. Verify parent inbox for PDF report email.

## Notes

- Gmail Apps Script has daily quota limits.
- For Flutter Web CORS errors, use the Cloudflare relay guide:
  - `frontend/CLOUDFLARE_RELAY_SETUP.md`
