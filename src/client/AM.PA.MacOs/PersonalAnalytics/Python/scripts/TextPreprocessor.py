from nltk.tokenize import word_tokenize
from nltk.corpus import stopwords

def processList(textList):
    return [process(x) for x in textList]

def process(text):
    text = text.lower()
    tokens = word_tokenize(text)
    stop = stopwords.words('english')
    tokens = [x for x in tokens if x not in stop]
    return tokens
