/**
 * LTP Native 模块
 *
 * 纯 D 语言实现的 LTP NLP 工具包
 *
 * 提供以下功能：
 * - CWS: 中文分词
 * - POS: 词性标注
 * - NER: 命名实体识别
 *
 * 使用示例：
 * ```d
 * import etc.ltp.native;
 *
 * // 使用统一接口
 * auto ltp = new LTPAnalyzer("model");
 * ltp.loadAll();
 * auto result = ltp.analyze("我爱北京天安门");
 * writeln(result);
 *
 * // 或单独使用各模块
 * auto cws = new CWSAnalyzer("model/cws_model.bin");
 * auto words = cws.predict("我爱北京天安门");
 * ```
 */
module etc.ltp.native;

public import etc.ltp.native.model;
public import etc.ltp.native.viterbi;
public import etc.ltp.native.features;
public import etc.ltp.native.cws;
public import etc.ltp.native.pos;
public import etc.ltp.native.ner;
public import etc.ltp.native.ltp;
