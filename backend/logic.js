function formatKeywords(keywords) {
    if (!keywords) return [];
    return keywords.map(k => k.trim());
}
module.exports = { formatKeywords };