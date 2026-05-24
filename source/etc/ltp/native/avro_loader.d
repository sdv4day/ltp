/**
 * Avro 模型加载器
 *
 * 从 Avro Object Container Files 加载 LTP 模型
 */
module etc.ltp.native.avro_loader;

import std.file;
import std.array;
import std.conv;
import std.zlib;
import avro.codec.binarydecoder;
import avro.parser;
import avro.schema;
import avro.type;
import avro.generic.genericdata;
import avro.generic.genericreader;
import etc.ltp.native.model;

/**
 * Avro 文件头信息
 */
struct AvroHeader {
    string schemaJson;
    string codecName;
}

/**
 * Avro 模型加载器
 */
struct AvroModelLoader {

    /**
     * 加载 CWS 模型
     *
     * 参数:
     *   path: Avro 文件路径
     *
     * 返回:
     *   CWS 模型实例
     */
    static CWSModel loadCWS(string path) {
        auto datum = readAvroDatum(path);
        return parseCWSModel(datum);
    }

    /**
     * 加载 POS 模型
     *
     * 参数:
     *   path: Avro 文件路径
     *
     * 返回:
     *   POS 模型实例
     */
    static POSModel loadPOS(string path) {
        auto datum = readAvroDatum(path);
        return parseLabelModel!POSModel(datum);
    }

    /**
     * 加载 NER 模型
     *
     * 参数:
     *   path: Avro 文件路径
     *
     * 返回:
     *   NER 模型实例
     */
    static NERModel loadNER(string path) {
        auto datum = readAvroDatum(path);
        return parseLabelModel!NERModel(datum);
    }

private:

    /**
     * 读取 Avro 文件并解码为 GenericDatum
     *
     * 参数:
     *   path: Avro 文件路径
     *
     * 返回:
     *   GenericDatum - 解码后的 Avro 数据
     */
    static GenericDatum readAvroDatum(string path) {
        auto fileData = cast(ubyte[]) std.file.read(path);
        auto decoder = binaryDecoder(fileData);

        decoder.readFixed(4);

        auto header = readHeader(decoder);

        decoder.readLong();

        auto parser = new Parser();
        Schema schema = parser.parseText(header.schemaJson);

        decoder.readFixed(16);

        long objectCount = decoder.readLong();
        long blockSize = decoder.readLong();

        auto blockData = decoder.readFixed(cast(size_t) blockSize);

        ubyte[] uncompressedData;
        if (header.codecName == "deflate") {
            uncompressedData = cast(ubyte[]) std.zlib.uncompress(blockData, blockSize, -15);
        } else {
            uncompressedData = blockData;
        }

        auto blockDecoder = binaryDecoder(uncompressedData);
        auto reader = new GenericReader(schema, blockDecoder);

        GenericDatum datum;
        reader.read(datum);

        return datum;
    }

    /**
     * 读取 Avro 文件头
     *
     * 参数:
     *   decoder: 二进制解码器
     *
     * 返回:
     *   AvroHeader - 包含 schema 和 codec 信息
     */
    static AvroHeader readHeader(T)(ref BinaryDecoder!T decoder) {
        AvroHeader header;
        header.codecName = "null";

        long mapEntries = decoder.readLong();

        for (long i = 0; i < mapEntries; i++) {
            string key = decoder.readString();
            auto valueBytes = decoder.readBytes();

            if (key == "avro.schema") {
                header.schemaJson = cast(string) valueBytes;
            } else if (key == "avro.codec") {
                header.codecName = cast(string) valueBytes;
            }
        }

        return header;
    }

    /**
     * 解析 CWS 模型数据
     */
    static CWSModel parseCWSModel(GenericDatum datum) {
        CWSModel model;

        auto record = datum.getValue!GenericRecord();

        auto features = record.fieldAt(1);
        if (features.getType() == Type.MAP) {
            auto map = features.getValue!GenericMap();
            foreach (key, value; map.getValue()) {
                model.model.features[key] = value.getValue!long;
            }
        }

        auto params = record.fieldAt(2);
        if (params.getType() == Type.ARRAY) {
            auto arr = params.getValue!GenericArray();
            model.model.parameters = new double[arr.length()];
            foreach (i, item; arr.getValue()) {
                model.model.parameters[i] = item.getValue!double;
            }
        }

        return model;
    }

    /**
     * 解析带标签定义的模型（POS/NER 通用）
     *
     * 参数:
     *   datum: Avro 解码数据
     *
     * 返回:
     *   T - POSModel 或 NERModel 实例
     */
    static T parseLabelModel(T)(GenericDatum datum) {
        T model;

        auto record = datum.getValue!GenericRecord();

        auto defField = record.fieldAt(0);
        if (defField.getType() == Type.RECORD) {
            auto defRecord = defField.getValue!GenericRecord();

            auto toLabels = defRecord.fieldAt(0);
            if (toLabels.getType() == Type.ARRAY) {
                auto arr = toLabels.getValue!GenericArray();
                model.definition.toLabels = new string[arr.length()];
                foreach (i, item; arr.getValue()) {
                    model.definition.toLabels[i] = item.getValue!string;
                    model.definition.labelsTo[model.definition.toLabels[i]] = i;
                }
            }
        }

        auto features = record.fieldAt(1);
        if (features.getType() == Type.MAP) {
            auto map = features.getValue!GenericMap();
            foreach (key, value; map.getValue()) {
                model.model.features[key] = value.getValue!long;
            }
        }

        auto params = record.fieldAt(2);
        if (params.getType() == Type.ARRAY) {
            auto arr = params.getValue!GenericArray();
            model.model.parameters = new double[arr.length()];
            foreach (i, item; arr.getValue()) {
                model.model.parameters[i] = item.getValue!double;
            }
        }

        return model;
    }
}

/**
 * 单元测试
 */
unittest {
    import std.stdio;
    import std.path;

    writeln("Testing AvroModelLoader...");

    string modelPath = buildPath("model", "cws_model.bin");

    if (exists(modelPath)) {
        auto model = AvroModelLoader.loadCWS(modelPath);
        writeln("CWS Model loaded from Avro:");
        writeln("  Features: ", model.model.featureCount());
        writeln("  Parameters: ", model.model.parameterCount());

        assert(model.model.featureCount() > 0);
        assert(model.model.parameterCount() > 0);
    } else {
        writeln("Model file not found, skipping test");
    }
}
