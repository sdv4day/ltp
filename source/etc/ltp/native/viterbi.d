/**
 * Viterbi 解码算法
 *
 * 用于序列标注任务的最优路径解码
 */
module etc.ltp.native.viterbi;

import std.algorithm;
import std.math;
import std.array;
import std.typecons : Tuple, tuple;

/**
 * Viterbi 解码器
 */
struct ViterbiDecoder {
    /**
     * 执行 Viterbi 解码
     *
     * 参数:
     *   features: 特征索引数组，每个位置有多个特征
     *   weights: 权重数组
     *   labelNum: 标签数量
     *   useTransition: 是否使用转移分数（默认 true）
     *
     * 返回:
     *   最优标签索引序列
     */
    static int[] decode(int[][] features, const double[] weights, int labelNum, bool useTransition = true) {
        if (features.length == 0) {
            return [];
        }

        int charNum = cast(int)features.length;
        int[] preMatrix = new int[charNum * labelNum];
        double[] scoreLast = new double[labelNum];
        double[] scoreNow = new double[labelNum];

        preMatrix[] = 0;
        scoreLast[] = -double.infinity;
        scoreNow[] = -double.infinity;

        foreach (label; 0 .. labelNum) {
            scoreLast[label] = scoreBase(features[0], label, weights, labelNum);
            preMatrix[label] = label;
        }

        foreach (i; 1 .. charNum) {
            int base = i * labelNum;

            foreach (label; 0 .. labelNum) {
                double scoreBaseVal = scoreBase(features[i], label, weights, labelNum);
                double maxScore = -double.infinity;
                int maxPrevLabel = 0;

                foreach (prevLabel; 0 .. labelNum) {
                    double transScore = 0.0;
                    if (useTransition) {
                        transScore = weights[prevLabel * labelNum + label];
                    }
                    double score = scoreLast[prevLabel] + scoreBaseVal + transScore;
                    if (score > maxScore) {
                        maxScore = score;
                        maxPrevLabel = prevLabel;
                    }
                }

                preMatrix[base + label] = maxPrevLabel;
                scoreNow[label] = maxScore;
            }

            swap(scoreLast, scoreNow);
        }

        int maxLabel = 0;
        double maxScoreVal = scoreLast[0];
        foreach (label; 1 .. labelNum) {
            if (scoreLast[label] > maxScoreVal) {
                maxScoreVal = scoreLast[label];
                maxLabel = label;
            }
        }

        int[] result = new int[charNum];
        int currentLabel = maxLabel;

        foreach_reverse (i; 0 .. charNum) {
            result[i] = currentLabel;
            currentLabel = preMatrix[i * labelNum + currentLabel];
        }

        return result;
    }

    /**
     * 计算基础分数
     *
     * 参数:
     *   featureIndices: 特征索引数组
     *   label: 标签索引
     *   weights: 权重数组
     *   labelNum: 标签数量
     *
     * 返回:
     *   该位置该标签的分数
     */
    static double scoreBase(int[] featureIndices, int label, const double[] weights, int labelNum) {
        double score = 0.0;
        foreach (featIdx; featureIndices) {
            if (featIdx >= 0) {
                size_t paramIdx = cast(size_t)(featIdx * labelNum + label);
                if (paramIdx < weights.length) {
                    score += weights[paramIdx];
                }
            }
        }
        return score;
    }

    /**
     * 简单解码（不使用 Viterbi，每个位置独立选择最优标签）
     *
     * 参数:
     *   features: 特征索引数组
     *   weights: 权重数组
     *   labelNum: 标签数量
     *
     * 返回:
     *   标签索引序列
     */
    static int[] simpleDecode(int[][] features, const double[] weights, int labelNum) {
        if (features.length == 0) {
            return [];
        }

        int[] result = new int[features.length];

        foreach (i, featIndices; features) {
            double maxScore = -double.infinity;
            int maxLabel = 0;

            foreach (label; 0 .. labelNum) {
                double score = scoreBase(featIndices, label, weights, labelNum);
                if (score > maxScore) {
                    maxScore = score;
                    maxLabel = label;
                }
            }

            result[i] = maxLabel;
        }

        return result;
    }
}

/**
 * SBME 标签转实体
 *
 * 将 S/B/M/E 标签序列转换为实体列表
 *
 * S: 单字词
 * B: 词首
 * M: 词中
 * E: 词尾
 */
struct SBMEConverter {
    /**
     * 将标签索引序列转换为实体范围
     *
     * 参数:
     *   labels: 标签索引序列 (0=S, 1=B, 2=M, 3=E)
     *
     * 返回:
     *   实体范围数组，每个元素为 (type, start, end)
     */
    static Tuple!(int, size_t, size_t)[] getEntities(int[] labels) {
        Tuple!(int, size_t, size_t)[] entities;

        size_t start = 0;
        int currentType = 0;

        foreach (i, label; labels) {
            switch (label) {
                case 0: // S - 单字词
                    entities ~= tuple(0, i, i);
                    start = i + 1;
                    currentType = 0;
                    break;

                case 1: // B - 词首
                    start = i;
                    currentType = 1;
                    break;

                case 2: // M - 词中
                    break;

                case 3: // E - 词尾
                    entities ~= tuple(currentType, start, i);
                    start = i + 1;
                    currentType = 0;
                    break;

                default:
                    break;
            }
        }

        if (start < labels.length && currentType == 1) {
            entities ~= tuple(currentType, start, labels.length - 1);
        }

        return entities;
    }

    /**
     * 将标签索引序列转换为词语范围
     *
     * 参数:
     *   labels: 标签索引序列
     *
     * 返回:
     *   词语范围数组，每个元素为 (start, end)
     */
    static Tuple!(size_t, size_t)[] getWords(int[] labels) {
        Tuple!(size_t, size_t)[] words;

        size_t start = 0;
        bool inWord = false;

        foreach (i, label; labels) {
            switch (label) {
                case 0: // S - 单字词
                    words ~= tuple(i, i + 1);
                    start = i + 1;
                    inWord = false;
                    break;

                case 1: // B - 词首
                    start = i;
                    inWord = true;
                    break;

                case 2: // M - 词中
                    break;

                case 3: // E - 词尾
                    words ~= tuple(start, i + 1);
                    start = i + 1;
                    inWord = false;
                    break;

                default:
                    break;
            }
        }

        if (inWord && start < labels.length) {
            words ~= tuple(start, labels.length);
        }

        return words;
    }
}

/**
 * BIO 标签转实体
 *
 * 将 BIO 标签序列转换为命名实体
 */
struct BIOConverter {
    /**
     * 将 BIO 标签序列转换为实体范围
     *
     * 参数:
     *   labels: 标签名称序列
     *   labelToIndex: 标签到索引的映射
     *
     * 返回:
     *   实体数组，每个元素为 (type, start, end)
     */
    static Tuple!(string, size_t, size_t)[] getEntities(string[] labels, string[string] labelToIndex) {
        Tuple!(string, size_t, size_t)[] entities;

        size_t start = 0;
        string currentType = "";
        bool inEntity = false;

        foreach (i, label; labels) {
            if (label.startsWith("B-")) {
                if (inEntity) {
                    entities ~= tuple(currentType, start, i);
                }
                start = i;
                currentType = label[2 .. $];
                inEntity = true;
            } else if (label.startsWith("I-")) {
                string type = label[2 .. $];
                if (!inEntity || type != currentType) {
                    if (inEntity) {
                        entities ~= tuple(currentType, start, i);
                    }
                    start = i;
                    currentType = type;
                    inEntity = true;
                }
            } else if (label == "O") {
                if (inEntity) {
                    entities ~= tuple(currentType, start, i);
                    inEntity = false;
                }
            }
        }

        if (inEntity) {
            entities ~= tuple(currentType, start, labels.length);
        }

        return entities;
    }
}
