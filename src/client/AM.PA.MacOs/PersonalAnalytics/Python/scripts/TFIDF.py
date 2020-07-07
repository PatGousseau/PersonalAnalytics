from sklearn.feature_extraction.text import TfidfVectorizer
from nltk.stem.snowball import SnowballStemmer
import TextPreprocessor

def fit(textList):
    textList = TextPreprocessor.processList(textList)
    stemmer = SnowballStemmer('english')
    sentences = []

    for text in textList:
        arr = []
        for word in text:
            stem = stemmer.stem(word)
            arr.append(stem)
        sentences.append(" ".join(arr))

    tfidf = TfidfVectorizer()

    if(len(sentences) > 0):
        tfidf.fit(sentences)

    return tfidf

def transform(tfidf, text):
    if(not hasattr(tfidf, "vocabulary_")):
        return {}

    text = TextPreprocessor.process(text)
    stemmer = SnowballStemmer('english')
    arr = []
    for word in text:
        stem = stemmer.stem(word)
        arr.append(stem)

    scores = list(tfidf.transform([" ".join(arr)]).toarray()[0])
    names = tfidf.get_feature_names()

    return {names[i]:scores[i] for i in range(len(scores))}
