// backend/server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { ComprehendClient, DetectSentimentCommand, DetectKeyPhrasesCommand } = require("@aws-sdk/client-comprehend");
const { Pool } = require('pg'); // PostgreSQL client for RDS

const app = express();
const port = 3000;

app.use(cors());
app.use(bodyParser.json());

// Initialize AWS Comprehend
const comprehend = new ComprehendClient({ region: "eu-north-1" }); 

// Initialize PostgreSQL Pool using Environment Variables
const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER || 'dbadmin',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'feedbackdb',
  port: 5432,
});

// Database Initialization
const initDb = async () => {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS feedback (
                id SERIAL PRIMARY KEY,
                text TEXT,
                sentiment TEXT,
                keywords TEXT,
                timestamp TEXT
            )
        `);
        console.log("RDS Database connected and table verified.");
    } catch (err) {
        console.error("Database connection error:", err);
    }
};
initDb();

app.get('/', (req, res) => {
    res.send('Backend is running and connected to RDS! 🚀');
});

// Submit Feedback
app.post('/api/feedback', async (req, res) => {
    try {
        const text = req.body.text;
        if (!text) return res.status(400).json({ error: "Text is required" });

        // 1. AI Analysis
        const sentimentResponse = await comprehend.send(new DetectSentimentCommand({ Text: text, LanguageCode: "en" }));
        const keywordResponse = await comprehend.send(new DetectKeyPhrasesCommand({ Text: text, LanguageCode: "en" }));
        
        const sentiment = sentimentResponse.Sentiment;
        const keywords = keywordResponse.KeyPhrases.map(kp => kp.Text);

        // 2. Save to RDS
        const timestamp = new Date().toISOString();
        const sql = `INSERT INTO feedback (text, sentiment, keywords, timestamp) VALUES ($1, $2, $3, $4) RETURNING id`;
        const result = await pool.query(sql, [text, sentiment, JSON.stringify(keywords), timestamp]);

        res.json({
            success: true,
            data: { id: result.rows[0].id, text, sentiment, keywords, timestamp }
        });
    } catch (error) {
        console.error("Error:", error);
        res.status(500).json({ error: "Processing failed", details: error.message });
    }
});

// Get Feedback for Admin Dashboard
app.get('/api/feedback', async (req, res) => {
    try {
        const result = await pool.query(`SELECT * FROM feedback ORDER BY id DESC`);
        const formattedRows = result.rows.map(row => ({
            ...row,
            keywords: JSON.parse(row.keywords)
        }));
        res.json(formattedRows);
    } catch (err) {
        res.status(500).json({ error: "Database fetch failed" });
    }
});

app.listen(port, () => console.log(`Server listening on port ${port}`));