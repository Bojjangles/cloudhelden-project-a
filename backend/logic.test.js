const { formatKeywords } = require('./logic');

test('formats keywords correctly', () => {
    expect(formatKeywords([' AI ', 'Cloud '])).toEqual(['AI', 'Cloud']);
});
// Add 4 more simple tests here to reach the mandatory 5!