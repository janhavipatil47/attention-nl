import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import nodemailer from 'nodemailer';
import { PDFDocument, StandardFonts, rgb } from 'pdf-lib';

admin.initializeApp();

const GMAIL_SMTP_USER = defineSecret('GMAIL_SMTP_USER');
const GMAIL_SMTP_PASS = defineSecret('GMAIL_SMTP_PASS');

function toNumber(value: unknown): number {
  return typeof value === 'number' ? value : 0;
}

async function buildPdf(report: Record<string, unknown>): Promise<Uint8Array> {
  const scores = (report.scores as Record<string, unknown> | undefined) ?? {};
  const insights = (report.insights as string[] | undefined) ?? [];
  const recommendations = (report.recommendations as string[] | undefined) ?? [];

  const pdf = await PDFDocument.create();
  const page = pdf.addPage([612, 792]);
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let y = 760;
  const left = 40;

  const writeLine = (text: string, size = 12, useBold = false) => {
    page.drawText(text, {
      x: left,
      y,
      size,
      font: useBold ? bold : font,
      color: rgb(0.12, 0.15, 0.2),
    });
    y -= size + 8;
  };

  writeLine('NeuroLearn Assessment Report', 18, true);
  writeLine(`Child: ${String(report.childName ?? 'Child')}`);
  writeLine(`Parent: ${String(report.parentName ?? 'Parent')}`);
  writeLine(`Age: ${String(report.childAge ?? '-')}`);
  writeLine(`Status: ${String(report.statusLabel ?? 'Assessment Complete')}`);
  writeLine('', 6);

  writeLine('Scores', 14, true);
  writeLine(`Overall: ${toNumber(scores.overall).toFixed(0)}%`);
  writeLine(`Confidence: ${toNumber(scores.confidence).toFixed(0)}%`);
  writeLine(`Reading: ${toNumber(scores.reading).toFixed(0)}%`);
  writeLine(`Writing: ${toNumber(scores.writing).toFixed(0)}%`);
  writeLine(`Attention: ${toNumber(scores.attention).toFixed(0)}%`);
  writeLine(`Memory: ${toNumber(scores.memory).toFixed(0)}%`);

  writeLine('', 6);
  writeLine('Insights', 14, true);
  for (const line of insights.slice(0, 6)) {
    writeLine(`- ${line}`);
  }

  writeLine('', 6);
  writeLine('Recommendations', 14, true);
  for (const line of recommendations.slice(0, 6)) {
    writeLine(`- ${line}`);
  }

  return pdf.save();
}

export const sendAssessmentReportEmail = onDocumentCreated(
  {
    document: 'assessment_reports/{reportId}',
    region: 'us-central1',
    retry: false,
    secrets: [GMAIL_SMTP_USER, GMAIL_SMTP_PASS],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.error('No snapshot data in trigger event.');
      return;
    }

    const reportId = event.params.reportId;
    const report = snapshot.data() as Record<string, unknown>;
    const parentEmail = String(report.parentEmail ?? '').trim();

    if (!parentEmail) {
      logger.error('Parent email is missing.');
      await snapshot.ref.update({
        'email.status': 'failed',
        'email.lastError': 'Missing parentEmail',
      });
      return;
    }

    const smtpUser = GMAIL_SMTP_USER.value();
    const smtpPass = GMAIL_SMTP_PASS.value();

    if (!smtpUser || !smtpPass) {
      logger.error('Missing Gmail SMTP environment variables.');
      await snapshot.ref.update({
        'email.status': 'failed',
        'email.lastError': 'Missing SMTP credentials',
      });
      return;
    }

    try {
      await snapshot.ref.update({
        'email.status': 'sending',
        'email.lastError': null,
      });

      const pdfBytes = await buildPdf(report);
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
      });

      const childName = String(report.childName ?? 'Child');
      const overallScore = toNumber((report.scores as Record<string, unknown> | undefined)?.overall);

      await transporter.sendMail({
        from: `NeuroLearn Reports <${smtpUser}>`,
        to: parentEmail,
        subject: `Assessment Report for ${childName}`,
        text: `Hello,\n\nAttached is ${childName}'s latest NeuroLearn assessment report.\nOverall score: ${overallScore.toFixed(0)}%.\n\nRegards,\nNeuroLearn Team`,
        attachments: [
          {
            filename: `${childName.replace(/\s+/g, '_')}_assessment_report.pdf`,
            content: Buffer.from(pdfBytes),
            contentType: 'application/pdf',
          },
        ],
      });

      await snapshot.ref.update({
        'email.status': 'sent',
        'email.sentAt': admin.firestore.FieldValue.serverTimestamp(),
        'email.lastError': null,
      });
    } catch (error) {
      logger.error('Email send failed', error);
      await snapshot.ref.update({
        'email.status': 'failed',
        'email.lastError': String(error),
      });
    }

    logger.info(`Report processing complete for ${reportId}`);
  }
);
