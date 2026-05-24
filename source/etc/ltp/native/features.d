/**
 * 特征提取模块
 *
 * 实现 CWS/POS/NER 的特征模板
 */
module etc.ltp.native.features;

import std.string;
import std.array;
import std.utf;
import std.uni;
import std.typecons : Tuple, tuple;

/**
 * 字符类型枚举
 */
enum CharType : ubyte {
    Digit = 1,
    Roman = 2,
    Hiragana = 3,
    Katakana = 4,
    Kanji = 5,
    Other = 6
}

/**
 * 字符类型判断工具
 */
struct CharTypeUtils {
    /**
     * 获取字符类型
     *
     * 参数:
     *   c: Unicode 字符
     *
     * 返回:
     *   字符类型
     */
    static CharType getType(dchar c) {
        uint code = cast(uint)c;

        if ((code >= 0x30 && code <= 0x39) || (code >= 0xFF10 && code <= 0xFF19)) {
            return CharType.Digit;
        }
        if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A) ||
            (code >= 0xFF21 && code <= 0xFF3A) || (code >= 0xFF41 && code <= 0xFF5A)) {
            return CharType.Roman;
        }
        if (code >= 0x3040 && code <= 0x3096) {
            return CharType.Hiragana;
        }
        if ((code >= 0x30A0 && code <= 0x30FA) || (code >= 0x30FC && code <= 0x30FF) ||
            (code >= 0xFF66 && code <= 0xFF9F)) {
            return CharType.Katakana;
        }
        if ((code >= 0x3400 && code <= 0x4DBF) ||
            (code >= 0x4E00 && code <= 0x9FFF) ||
            (code >= 0xF900 && code <= 0xFAFF) ||
            (code >= 0x20000 && code <= 0x2A6DF) ||
            (code >= 0x2A700 && code <= 0x2B73F) ||
            (code >= 0x2B740 && code <= 0x2B81F) ||
            (code >= 0x2B820 && code <= 0x2CEAF) ||
            (code >= 0x2F800 && code <= 0x2FA1F)) {
            return CharType.Kanji;
        }

        return CharType.Other;
    }
}

/**
 * CWS 特征提取器
 *
 * 字符级特征模板:
 * - ch[-2], ch[-1], ch[0], ch[+1], ch[+2]
 * - ch[-2]ch[-1], ch[-1]ch[0], ch[0]ch[+1], ch[+1]ch[+2]
 * - ch[-2]ch[0], ch[0]ch[+2] (cross-char)
 * - TYPE(ch[0]), TYPE(ch[-1]), TYPE(ch[+1])
 */
struct CWSFeatureExtractor {
    /**
     * 提取字符特征
     *
     * 参数:
     *   sentence: 输入句子
     *   buffer: 特征缓冲区（用于减少内存分配）
     *
     * 返回:
     *   (字符索引数组, 特征数组)
     */
    static Tuple!(size_t[], string[][]) extractFeatures(string sentence, ref string buffer) {
        size_t[] indices;
        string[][] features;

        dchar[] chars;
        size_t[] byteIndices;

        size_t byteIdx = 0;
        foreach (dchar c; sentence.byCodePoint) {
            if (!isWhite(c)) {
                chars ~= c;
                byteIndices ~= byteIdx;
            }
            byteIdx += codeLength!char(c);
        }

        if (chars.length == 0) {
            return tuple(indices, features);
        }

        indices.reserve(chars.length + 1);
        features.reserve(chars.length);

        dchar nullChar = '\u0000';

        foreach (i, curChar; chars) {
            string[] featList;

            dchar pre2Char = (i >= 2) ? chars[i - 2] : nullChar;
            dchar preChar = (i >= 1) ? chars[i - 1] : nullChar;
            dchar nextChar = (i + 1 < chars.length) ? chars[i + 1] : nullChar;
            dchar next2Char = (i + 2 < chars.length) ? chars[i + 2] : nullChar;

            featList ~= formatFeature("2", curChar);

            featList ~= formatFeature("b", CharTypeUtils.getType(curChar));

            if (preChar != nullChar) {
                featList ~= formatFeature("1", preChar);
                featList ~= formatFeature("6", preChar, curChar);
                featList ~= formatFeature("c", CharTypeUtils.getType(preChar));
                featList ~= formatFeature("d", CharTypeUtils.getType(preChar), CharTypeUtils.getType(curChar));

                if (pre2Char != nullChar) {
                    featList ~= formatFeature("0", pre2Char);
                    featList ~= formatFeature("5", pre2Char, preChar);
                    featList ~= formatFeature("9", pre2Char, curChar);
                }

                if (pre2Char == curChar) {
                    featList ~= "c";
                }
            }

            if (nextChar != nullChar) {
                featList ~= formatFeature("3", nextChar);
                featList ~= formatFeature("7", curChar, nextChar);
                featList ~= formatFeature("d", CharTypeUtils.getType(nextChar));

                if (next2Char != nullChar) {
                    featList ~= formatFeature("4", next2Char);
                    featList ~= formatFeature("8", nextChar, next2Char);
                    featList ~= formatFeature("a", curChar, next2Char);
                }
            }

            indices ~= byteIndices[i];
            features ~= featList;
        }

        indices ~= sentence.length;

        return tuple(indices, features);
    }

    /**
     * 格式化单字符特征
     */
    static string formatFeature(string prefix, dchar c) {
        char[4] buf;
        size_t len = encode(buf, c);
        return prefix ~ cast(string)buf[0 .. len];
    }

    /**
     * 格式化双字符特征
     */
    static string formatFeature(string prefix, dchar c1, dchar c2) {
        char[4] buf1, buf2;
        size_t len1 = encode(buf1, c1);
        size_t len2 = encode(buf2, c2);
        return prefix ~ cast(string)buf1[0 .. len1] ~ cast(string)buf2[0 .. len2];
    }

    /**
     * 格式化字符类型特征
     */
    static string formatFeature(string prefix, CharType type) {
        import std.conv : to;
        return prefix ~ to!string(cast(int)type);
    }

    /**
     * 格式化双字符类型特征
     */
    static string formatFeature(string prefix, CharType t1, CharType t2) {
        import std.conv : to;
        return prefix ~ to!string(cast(int)t1) ~ to!string(cast(int)t2);
    }
}

/**
 * POS 特征提取器
 *
 * 词语级特征模板
 */
struct POSFeatureExtractor {
    /**
     * 提取词语特征
     *
     * 参数:
     *   words: 分词结果
     *
     * 返回:
     *   特征数组
     */
    static string[][] extractFeatures(string[] words) {
        string[][] features;
        features.reserve(words.length);

        foreach (i, word; words) {
            string[] featList;

            featList ~= formatWordFeature("w0", word);

            if (i > 0) {
                featList ~= formatWordFeature("w-1", words[i - 1]);
                featList ~= formatWordFeature("w-1w0", words[i - 1], word);
            }

            if (i > 1) {
                featList ~= formatWordFeature("w-2", words[i - 2]);
            }

            if (i + 1 < words.length) {
                featList ~= formatWordFeature("w+1", words[i + 1]);
                featList ~= formatWordFeature("w0w+1", word, words[i + 1]);
            }

            if (i + 2 < words.length) {
                featList ~= formatWordFeature("w+2", words[i + 2]);
            }

            if (i > 0 && i + 1 < words.length) {
                featList ~= formatWordFeature("w-1w+1", words[i - 1], words[i + 1]);
            }

            auto chars = word.byCodePoint.array;
            dchar firstChar = chars[0];
            dchar lastChar = chars[$ - 1];

            featList ~= formatCharFeature("c0", firstChar);
            featList ~= formatCharFeature("c-1", lastChar);

            if (chars.length > 1) {
                featList ~= formatCharFeature("c1", chars[1]);
                featList ~= formatCharFeature("c-2", chars[$ - 2]);
            }

            featList ~= formatCharTypeFeature("t0", CharTypeUtils.getType(firstChar));
            featList ~= formatCharTypeFeature("t-1", CharTypeUtils.getType(lastChar));

            features ~= featList;
        }

        return features;
    }

    static string formatWordFeature(string prefix, string word) {
        return prefix ~ word;
    }

    static string formatWordFeature(string prefix, string w1, string w2) {
        return prefix ~ w1 ~ w2;
    }

    static string formatCharFeature(string prefix, dchar c) {
        char[4] buf;
        size_t len = encode(buf, c);
        return prefix ~ cast(string)buf[0 .. len];
    }

    static string formatCharTypeFeature(string prefix, CharType type) {
        import std.conv : to;
        return prefix ~ to!string(cast(int)type);
    }
}

/**
 * NER 特征提取器
 *
 * 基于词语和词性的特征模板
 */
struct NERFeatureExtractor {
    /**
     * 提取 NER 特征
     *
     * 参数:
     *   words: 分词结果
     *   posTags: 词性标注结果
     *
     * 返回:
     *   特征数组
     */
    static string[][] extractFeatures(string[] words, string[] posTags) {
        assert(words.length == posTags.length, "Words and POS tags must have same length");

        string[][] features;
        features.reserve(words.length);

        foreach (i, word; words) {
            string[] featList;
            string pos = posTags[i];

            featList ~= formatWordFeature("w0", word);
            featList ~= formatPOSFeature("p0", pos);
            featList ~= formatWordPOSFeature("w0p0", word, pos);

            if (i > 0) {
                featList ~= formatWordFeature("w-1", words[i - 1]);
                featList ~= formatPOSFeature("p-1", posTags[i - 1]);
                featList ~= formatPOSFeature("p-1p0", posTags[i - 1], pos);
                featList ~= formatWordPOSFeature("w-1p-1", words[i - 1], posTags[i - 1]);
            }

            if (i > 1) {
                featList ~= formatWordFeature("w-2", words[i - 2]);
                featList ~= formatPOSFeature("p-2", posTags[i - 2]);
            }

            if (i + 1 < words.length) {
                featList ~= formatWordFeature("w+1", words[i + 1]);
                featList ~= formatPOSFeature("p+1", posTags[i + 1]);
                featList ~= formatPOSFeature("p0p+1", pos, posTags[i + 1]);
                featList ~= formatWordPOSFeature("w+1p+1", words[i + 1], posTags[i + 1]);
            }

            if (i + 2 < words.length) {
                featList ~= formatWordFeature("w+2", words[i + 2]);
                featList ~= formatPOSFeature("p+2", posTags[i + 2]);
            }

            dchar firstChar = word.byCodePoint.front;
            dchar lastChar = word.byCodePoint.back;

            featList ~= formatCharFeature("c0", firstChar);
            featList ~= formatCharFeature("c-1", lastChar);
            featList ~= formatCharTypeFeature("t0", CharTypeUtils.getType(firstChar));
            featList ~= formatCharTypeFeature("t-1", CharTypeUtils.getType(lastChar));

            features ~= featList;
        }

        return features;
    }

    static string formatWordFeature(string prefix, string word) {
        return prefix ~ word;
    }

    static string formatPOSFeature(string prefix, string pos) {
        return prefix ~ pos;
    }

    static string formatPOSFeature(string prefix, string p1, string p2) {
        return prefix ~ p1 ~ p2;
    }

    static string formatWordPOSFeature(string prefix, string word, string pos) {
        return prefix ~ word ~ pos;
    }

    static string formatCharFeature(string prefix, dchar c) {
        char[4] buf;
        size_t len = encode(buf, c);
        return prefix ~ cast(string)buf[0 .. len];
    }

    static string formatCharTypeFeature(string prefix, CharType type) {
        import std.conv : to;
        return prefix ~ to!string(cast(int)type);
    }
}

/**
 * 特征索引转换器
 */
struct FeatureIndexer {
    /**
     * 将字符串特征转换为特征索引
     *
     * 参数:
     *   features: 字符串特征数组
     *   featureDict: 特征字典
     *
     * 返回:
     *   特征索引数组
     */
    static int[][] toIndices(string[][] features, const long[string] featureDict) {
        int[][] result;
        result.reserve(features.length);

        foreach (featList; features) {
            int[] indices;
            indices.reserve(featList.length);

            foreach (feat; featList) {
                if (auto ptr = feat in featureDict) {
                    indices ~= cast(int)*ptr;
                }
            }

            result ~= indices;
        }

        return result;
    }
}
