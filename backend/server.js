// backend/server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { ComprehendClient, DetectSentimentCommand } = require("@aws-sdk/client-comprehend");

const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Initialize AWS Comprehend Client
// It automatically looks for credentials in your ~/.aws/credentials file!
const comprehend = new ComprehendClient({ region: "eu-central-1" }); // Or your preferred region

// In-memory "Database" (Just for today!)
const feedbackStore = [];

// Route 1: The "Hello" check
app.get('/', (req, res) => {
    res.send('Backend is running and ready to analyze emotions! 🚀');
});

// Route 2: Receive Feedback & Analyze Sentiment
app.post('/api/feedback', async (req, res) => {
    const { text } = req.body;

    if (!text) {
        return res.status(400).json({ error: "Please provide some text!" });
    }

    console.log(`Analyzing: "${text}"...`);

    try {
        // 1. Ask AWS: "How does this text feel?"
        const command = new DetectSentimentCommand({
            LanguageCode: "en", // or "de" for German
            Text: text
        });
        const response = await comprehend.send(command);

        // 2. Create the record
        const feedbackEntry = {
            id: Date.now(),
            text: text,
            sentiment: response.Sentiment, // POSITIVE, NEGATIVE, NEUTRAL, MIXED
            confidence: response.SentimentScore,
            timestamp: new Date()
        };

        // 3. Save to our "fake" database
        feedbackStore.push(feedbackEntry);

        console.log("Result:", response.Sentiment);
        res.json({ success: true, data: feedbackEntry });

    } catch (error) {
        console.error("AWS Error:", error);
        res.status(500).json({ error: "Failed to analyze sentiment", details: error.message });
    }
});

// Route 3: Get all feedback (for the Admin Dashboard later)
app.get('/api/feedback', (req, res) => {
    res.json(feedbackStore);
});

// Start the server
app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});