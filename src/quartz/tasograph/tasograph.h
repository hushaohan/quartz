#pragma once

#include "../context/context.h"
#include "../context/rule_parser.h"
#include "../dag/dag.h"
#include "../dataset/equivalence_set.h"
#include "../gate/gate.h"
#include "../device/device.h"
#include "../parser/qasm_parser.h"

#include <chrono>
#include <fstream>
#include <iostream>
#include <map>
#include <queue>
#include <set>
#include <unordered_map>
#include <utility>
#include <vector>

namespace quartz {

#define eps 1e-6

    bool equal_to_2k_pi(double d);

    class Op {
    public:
        Op(void);

        Op(size_t _guid, Gate *_ptr) : guid(_guid), ptr(_ptr) {}

        inline bool operator==(const Op &b) const {
            if (guid != b.guid)
                return false;
            if (ptr != b.ptr)
                return false;
            return true;
        }

        inline bool operator!=(const Op &b) const {
            if (guid != b.guid)
                return true;
            if (ptr != b.ptr)
                return true;
            return false;
        }

        inline bool operator<(const Op &b) const {
            if (guid != b.guid)
                return guid < b.guid;
            if (ptr != b.ptr)
                return ptr < b.ptr;
            return false;
        }

        Op &operator=(const Op &op) {
            guid = op.guid;
            ptr = op.ptr;
            parameter_string = op.parameter_string;
            return *this;
        }

        static const Op INVALID_OP;

    public:
        size_t guid;
        Gate *ptr;
        std::string parameter_string;
    };

    class OpCompare {
    public:
        bool operator()(const Op &a, const Op &b) const {
            if (a.guid != b.guid)
                return a.guid < b.guid;
            return a.ptr < b.ptr;
        };
    };

    class OpHash {
    public:
        size_t operator()(const Op &a) const {
            std::hash<size_t> hash_fn;
            return hash_fn(a.guid) * 17 + hash_fn((size_t) (a.ptr));
        }
    };

    class Pos {
    public:
        Pos() {
            op = Op();
            idx = 0;
        }

        Pos(const Pos &b) {
            op = b.op;
            idx = b.idx;
        }

        inline bool operator<(const Pos &b) const {
            if (op != b.op)
                return op < b.op;
            if (idx != b.idx)
                return idx < b.idx;
            return false;
        }

        Pos &operator=(const Pos &pos) {
            op = pos.op;
            idx = pos.idx;
            return *this;
        }

        Pos(Op op_, int idx_) : op(op_), idx(idx_) {}

        Op op;
        int idx;
    };

    inline bool operator==(const Pos &a, const Pos &b) {
        if (a.op != b.op)
            return false;
        if (a.idx != b.idx)
            return false;
        return true;
    }

    inline bool operator!=(const Pos &a, const Pos &b) {
        if (a.op != b.op)
            return true;
        if (a.idx != b.idx)
            return true;
        return false;
    }

    class PosHash {
    public:
        size_t operator()(const Pos &a) const {
            std::hash<size_t> hash_fn;
            OpHash op_hash;
            return op_hash(a.op) * 17 + hash_fn(a.idx);
        }
    };

    class PosCompare {
    public:
        bool operator()(const Pos &a, const Pos &b) const {
            if (a.op != b.op)
                return a.op < b.op;
            return a.idx < b.idx;
        }
    };

    class Tensor {
    public:
        Tensor(void);

        int idx;
        Op op;
    };

    struct Edge {
        Edge(void);

        Edge(const Op &_srcOp, const Op &_dstOp, int _srcIdx, int _dstIdx);

        Edge(const Op &_srcOp, const Op &_dstOp, int _srcIdx, int _dstIdx, int _logical_qubit_idx,
             int _physical_qubit_idx);

        mutable Op srcOp, dstOp;
        mutable int srcIdx, dstIdx;
        mutable int logical_qubit_idx, physical_qubit_idx;
    };

    struct EdgeCompare {
        bool operator()(const Edge &a, const Edge &b) const {
            if (!(a.srcOp == b.srcOp))
                return a.srcOp < b.srcOp;
            if (!(a.dstOp == b.dstOp))
                return a.dstOp < b.dstOp;
            if (a.srcIdx != b.srcIdx)
                return a.srcIdx < b.srcIdx;
            if (a.dstIdx != b.dstIdx)
                return a.dstIdx < b.dstIdx;
            return false;
        };
    };

    enum class MappingStatus {
        VALID,
        INPUT_QUBIT_TOO_MANY_OUTPUTS,
        INPUT_QUBIT_HAS_INPUT,
        INPUT_QUBIT_MAPPING_MISMATCH,
        NON_SWAP_PHYSICAL_MISMATCH,
        NON_SWAP_LOGICAL_MISMATCH,
        SWAP_PHYSICAL_MISMATCH,
        SWAP_LOGICAL_MISMATCH,
        SERIAL_MISMATCH,
    };

    enum class InitialMappingType {
        TRIVIAL, SABRE, RANDOM
    };

    struct GraphState {
    public:
        // node related
        int number_of_nodes;
        std::vector<int> node_id;
        std::vector<bool> is_input;
        std::vector<int> input_logical_idx;
        std::vector<int> input_physical_idx;
        std::vector<int> node_type;
        // edge related
        int number_of_edges;
        std::vector<int> edge_from;
        std::vector<int> edge_to;
        std::vector<bool> edge_reversed;
        std::vector<int> edge_logical_idx;
        std::vector<int> edge_physical_idx;
    };

    // The following struct is used in final qasm output.
    struct OutputGateRepresentation {
    public:
        OutputGateRepresentation() = delete;

        OutputGateRepresentation(bool _is_single_qubit_gate, GateType _gate_type, int _logical_idx0,
                                 int _logical_idx1, std::string _parameter_string="")
                : is_single_qubit_gate(_is_single_qubit_gate), gate_type(_gate_type),
                  logical_idx0(_logical_idx0), logical_idx1(_logical_idx1),
                  parameter_string(std::move(_parameter_string)) {}

    public:
        bool is_single_qubit_gate;
        GateType gate_type;
        std::string parameter_string;
        int logical_idx0;
        int logical_idx1;
    };

    bool operator==(const OutputGateRepresentation &g1, const OutputGateRepresentation &g2);

    class GraphXfer;

    class Graph {
    public:
        Graph(Context *ctx);

        Graph(Context *ctx, const DAG *dag);

        Graph(const Graph &graph);

        void _construct_pos_2_logical_qubit();

        void add_edge(const Op &srcOp, const Op &dstOp, int srcIdx, int dstIdx);

        bool has_edge(const Op &srcOp, const Op &dstOp, int srcIdx, int dstIdx) const;

        Op add_qubit(int qubit_idx);

        Op add_parameter(const ParamType p);

        Op new_gate(GateType gt);

        bool has_loop() const;

        size_t hash();

        bool equal(const Graph &other) const;

        bool check_correctness();

        int specific_gate_count(GateType gate_type) const;

        [[nodiscard]] float total_cost() const;

        [[nodiscard]] int gate_count() const;

        [[nodiscard]] int circuit_depth() const;

        size_t get_next_special_op_guid();

        size_t get_special_op_guid();

        void set_special_op_guid(size_t _special_op_guid);

        std::shared_ptr<Graph> context_shift(Context *src_ctx, Context *dst_ctx,
                                             Context *union_ctx,
                                             RuleParser *rule_parser,
                                             bool ignore_toffoli = false);

        std::shared_ptr<Graph>
        optimize(float alpha, int budget, bool print_subst, Context *ctx,
                 const std::string &equiv_file_name, bool use_simulated_annealing,
                 bool enable_early_stop, bool use_rotation_merging_in_searching,
                 GateType target_rotation, std::string circuit_name = "",
                 int timeout = 86400 /*1 day*/);

        std::shared_ptr<Graph> optimize(std::vector<GraphXfer *> xfers,
                                        double gate_count_upper_bound,
                                        std::string circuit_name, bool print_message,
                                        int timeout = 86400 /*1 day*/);

        void constant_and_rotation_elimination();

        void rotation_merging(GateType target_rotation);

        std::string to_qasm(bool print_result, bool print_id) const;

        void to_qasm(const std::string &save_filename, bool print_result,
                     bool print_id) const;

        template<class _CharT, class _Traits>
        static std::shared_ptr<Graph>
        _from_qasm_stream(Context *ctx,
                          std::basic_istream<_CharT, _Traits> &qasm_stream);

        static std::shared_ptr<Graph> from_qasm_file(Context *ctx,
                                                     const std::string &filename);

        static std::shared_ptr<Graph> from_qasm_str(Context *ctx,
                                                    const std::string qasm_str);

        void draw_circuit(const std::string &qasm_str,
                          const std::string &save_filename);

        size_t get_num_qubits() const;

        void print_qubit_ops();

        std::shared_ptr<Graph> toffoli_flip_greedy(GateType target_rotation,
                                                   GraphXfer *xfer,
                                                   GraphXfer *inverse_xfer);

        void toffoli_flip_greedy_with_trace(GateType target_rotation, GraphXfer *xfer,
                                            GraphXfer *inverse_xfer,
                                            std::vector<int> &trace);

        std::shared_ptr<Graph>
        toffoli_flip_by_instruction(GateType target_rotation, GraphXfer *xfer,
                                    GraphXfer *inverse_xfer,
                                    std::vector<int> instruction);

        std::vector<size_t> appliable_xfers(Op op,
                                            const std::vector<GraphXfer *> &) const;

        std::vector<size_t>
        appliable_xfers_parallel(Op op, const std::vector<GraphXfer *> &) const;

        bool xfer_appliable(GraphXfer *xfer, Op op) const;

        std::shared_ptr<Graph> apply_xfer(GraphXfer *xfer, Op op,
                                          bool eliminate_rotation = false);

        std::pair<std::shared_ptr<Graph>, std::vector<int>>
        apply_xfer_and_track_node(GraphXfer *xfer, Op op,
                                  bool eliminate_rotation = false);

        void all_ops(std::vector<Op> &ops);

        void all_edges(std::vector<Edge> &edges);

        void topology_order_ops(std::vector<Op> &ops) const;

        std::shared_ptr<Graph> ccz_flip_t(Context *ctx);

        std::shared_ptr<Graph> ccz_flip_greedy_rz();

        std::shared_ptr<Graph> ccz_flip_greedy_u1();

        // physical mapping related
        void init_physical_mapping(InitialMappingType mapping_type, const std::shared_ptr<DeviceTopologyGraph> &device,
                                   int pass, bool use_extensive, double w_value);

        void _trivial_mapping();

        void _random_mapping(const std::shared_ptr<DeviceTopologyGraph> &device);

        void _sabre_mapping(const std::shared_ptr<DeviceTopologyGraph> &device, int pass,
                            bool use_extensive, double w_value);

        void propagate_mapping();

        MappingStatus check_mapping_correctness();

        double circuit_implementation_cost(const std::shared_ptr<DeviceTopologyGraph> &device);

        // physical mapping with RL
        void add_swap(const Edge &e1, const Edge &e2);

        // utils
        void set_physical_mapping(const std::vector<int> &logical2physical);

        GraphState convert_circuit_to_state(int num_layers, bool include_forward_edge);

        std::map<Op, int, OpCompare> get_topology_ordering();

        std::set<Op, OpCompare> get_front_layers(int num_layers, bool include_input);


    private:
        void replace_node(Op oldOp, Op newOp);

        void remove_node(Op oldOp);

        void remove_edge(Op srcOp, Op dstOp);

        uint64_t xor_bitmap(uint64_t src_bitmap, int src_idx, uint64_t dst_bitmap,
                            int dst_idx);

        void explore(Pos pos, bool left, std::unordered_set<Pos, PosHash> &covered);

        void expand(Pos pos, bool left, GateType target_rotation,
                    std::unordered_set<Pos, PosHash> &covered,
                    std::unordered_map<int, Pos> &anchor_point,
                    std::unordered_map<Pos, int, PosHash> pos_to_qubits,
                    std::queue<int> &todo_qubits);

        void remove(Pos pos, bool left, std::unordered_set<Pos, PosHash> &covered);

        bool moveable(GateType tp);

        bool move_forward(Pos &pos, bool left);

        bool merge_2_rotation_op(Op op_0, Op op_1);

        std::shared_ptr<Graph> _match_rest_ops(GraphXfer *xfer, size_t depth,
                                               size_t ignore_depth,
                                               size_t min_guid) const;

    public:
        Context *context;
        std::map<Op, std::set<Edge, EdgeCompare>, OpCompare> inEdges, outEdges;
        std::map<Op, ParamType> constant_param_values;
        std::unordered_map<Op, int, OpHash> input_qubit_op_2_qubit_idx;
        std::unordered_map<Pos, int, PosHash> pos_2_logical_qubit;

        // physical mapping related
        // stores the mapping of input_qubit Ops -> <logical, physical idx>
        std::unordered_map<Op, std::pair<int, int>, OpHash> qubit_mapping_table;
        // stores the simplified gates after each op (we collapse gates forward when simplifying circuit)
        // this will only be filled if simplify circuit is called.
        std::unordered_map<Op, std::deque<OutputGateRepresentation>, OpHash> simplified_gates_after_op;

    private:
        size_t special_op_guid;
    };

}; // namespace quartz
