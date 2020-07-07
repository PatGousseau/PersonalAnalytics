from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

def cosineSimilarity(vals1, vals2):
    assert(len(vals1) == len(vals2))
    v1 = [list(vals1)]
    v2 = [list(vals2)]
    
    return cosine_similarity(v1,v2)[0][0]


def average(scoresList):
    assert(len(scoresList) > 0)
    avg = scoresList[0]
    for i in range(1,len(scoresList)):
        avg = add(avg, scoresList[i])
    
    v = np.array(list(avg.values()))/len(scoresList)
    labels = list(avg.keys())
    
    return {labels[i]:v[i] for i in range(len(v))}
    
def add(scores1, scores2):
    assert(len(scores1) == len(scores2))
    labels = list(scores1.keys())
    v1 = np.array(list(scores1.values()))
    v2 = np.array(list(scores2.values()))
    r = v1 + v2
    
    return {labels[i]:r[i] for i in range(len(r))}
    
    
