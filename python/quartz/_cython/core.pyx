# distutils: language = c++

from cython.operator cimport dereference as deref
from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.utility cimport pair
from libcpp.memory cimport shared_ptr, make_shared, nullptr
from libcpp cimport bool
from CCore cimport GateType
from CCore cimport Gate
from CCore cimport DAG
from CCore cimport DAG_ptr
from CCore cimport GraphXfer
from CCore cimport Graph
from CCore cimport Op
from CCore cimport Context
from CCore cimport EquivalenceSet
from CCore cimport QASMParser
from CCore cimport Edge
from enum import Enum
import ctypes
import dgl
import torch

ctypedef GraphXfer* GraphXfer_ptr

# physical mapping
from CCore cimport Reward, GraphState, State, ActionType, Action
from CCore cimport SimplePhysicalEnv, BackendType
from CCore cimport SimpleInitialEnv, SimpleSearchEnv
from CCore cimport SimpleHybridEnv


def get_gate_type_from_str(gate_type_str):
    if gate_type_str == "h": return GateType.h
    if gate_type_str == "x": return GateType.x
    if gate_type_str == "y": return GateType.y
    if gate_type_str == "rx": return GateType.rx
    if gate_type_str == "ry": return GateType.ry
    if gate_type_str == "rz": return GateType.rz
    if gate_type_str == "cx": return GateType.cx
    if gate_type_str == "ccx" :return GateType.ccx
    if gate_type_str == "add" :return GateType.add
    if gate_type_str == "neg" :return GateType.neg
    if gate_type_str == "z" :return GateType.z
    if gate_type_str == "s" :return GateType.s
    if gate_type_str == "sdg" :return GateType.sdg
    if gate_type_str == "t" :return GateType.t
    if gate_type_str == "tdg" :return GateType.tdg
    if gate_type_str == "ch" :return GateType.ch
    if gate_type_str == "swap" :return GateType.swap
    if gate_type_str == "p" :return GateType.p
    if gate_type_str == "pdg" :return GateType.pdg
    if gate_type_str == "u1" :return GateType.u1
    if gate_type_str == "u2" :return GateType.u2
    if gate_type_str == "u3" :return GateType.u3
    if gate_type_str == "ccz" :return GateType.ccz
    if gate_type_str == "cz" :return GateType.cz
    if gate_type_str == "input_qubit" :return GateType.input_qubit
    if gate_type_str == "input_param" :return GateType.input_param

cdef class PyQASMParser:
    cdef QASMParser *parser

    def __cinit__(self, *, QuartzContext context):
        self.parser = new QASMParser(context.context)

    def __dealloc__(self):
        pass

    def load_qasm(self, *, str filename) -> PyDAG:
        dag = PyDAG()
        filename_bytes = filename.encode('utf-8')
        success = self.parser.load_qasm(filename_bytes, dag.dag)
        assert(success, "Failed to load qasm file!")
        return dag

    def load_qasm_str(self, str qasm_str) -> PyDAG:
        dag = PyDAG()
        qasm_str_bytes = qasm_str.encode('utf-8')
        success = self.parser.load_qasm_str(qasm_str_bytes, dag.dag)
        assert(success, "Failed to load qasm file!")
        return dag

cdef class PyGate:
    cdef Gate *gate

    def __cinit__(self, *, str type_name=None, int num_qubits=-1, int num_parameters=-1):
        if type_name is not None and num_qubits >= 0 and num_parameters >= 0:
            gate_type = get_gate_type_from_str(type_name.lower())
            self.gate = new Gate(gate_type, num_qubits, num_parameters)
        else:
            self.gate = NULL

    def __dealloc__(self):
        pass

    cdef set_this(self, Gate* gate_):
        self.gate = gate_
        return self

    def is_commutative(self):
        return self.gate.is_commutative()

    def get_num_qubits(self):
        return self.gate.get_num_qubits()

    def get_num_parameters(self):
        return self.gate.get_num_parameters()

    def is_parameter_gate(self):
        return self.gate.is_parameter_gate()

    def is_quantum_gate(self):
        return self.gate.is_quantum_gate()

    def is_parametrized_gate(self):
        return self.gate.is_parametrized_gate()

    def is_toffoli_gate(self):
        return self.gate.is_toffoli_gate()

    @property
    def tp(self):
        return self.gate.tp

    @property
    def num_qubits(self):
        return self.gate.num_qubits

    @property
    def num_parameters(self):
        return self.gate.num_parameters

    @staticmethod
    def rebuild(GateType _type, int _num_qubits, int _num_params):
        gate = PyGate()
        inner_gate = new Gate(_type, _num_qubits, _num_params)
        gate.set_this(inner_gate)
        return gate

    def __reduce__(self):
        return (self.__class__.rebuild, (self.tp, self.num_qubits, self.num_parameters))


cdef class PyDAG:
    cdef DAG_ptr dag

    def __cinit__(self, *, int num_qubits=-1, int num_input_params=-1):
        if num_qubits >= 0 and num_input_params >= 0:
            self.dag = new DAG(num_qubits, num_input_params)
        else:
            self.dag = NULL

    def __dealloc__(self):
        pass

    cdef set_this(self, DAG_ptr dag_):
        self.dag = dag_
        return self

    @property
    def num_qubits(self):
        return self.dag.get_num_qubits()

    @property
    def num_input_parameters(self):
        return self.dag.get_num_input_parameters()

    @property
    def num_total_parameters(self):
        return self.dag.get_num_total_parameters()

    @property
    def num_internal_parameters(self):
        return self.dag.get_num_internal_parameters()

    @property
    def num_gates(self):
        return self.dag.get_num_gates()

cdef class PyXfer:
    cdef GraphXfer *graphXfer
    cdef bool is_nop

    def __cinit__(self, *, QuartzContext context=None, PyDAG dag_from=None, PyDAG dag_to=None, bool is_nop=False):
        self.is_nop = is_nop
        if context == None:
            self.graphXfer = NULL
        elif is_nop:
            self.graphXfer = NULL
        elif dag_from is not None and dag_to is not None:
            self.graphXfer = GraphXfer.create_GraphXfer(context.context, dag_from.dag, dag_to.dag, False)

    def __dealloc__(self):
        pass

    cdef set_this(self, GraphXfer *graphXfer_, bool is_nop=False):
        self.graphXfer = graphXfer_
        self.is_nop = is_nop
        # TODO: maybe delete before setting to None?
        if self.is_nop:
            self.graphXfer = NULL
        return self

    # TODO: raise exception if NULL or NOP
    @property
    def src_gate_count(self):
        return self.graphXfer.num_src_op()

    # TODO: raise exception if NULL or NOP
    @property
    def dst_gate_count(self):
        return self.graphXfer.num_dst_op()

    @property
    def is_nop(self):
        return self.is_nop

    @property
    def is_NOP(self):
        return self.is_nop

    @property
    def src_str(self):
        if self.is_nop:
            return 'NOP'
        return self.graphXfer.src_str().decode('utf-8')

    @property
    def dst_str(self):
        if self.is_nop:
            return 'NOP'
        return self.graphXfer.dst_str().decode('utf-8')

cdef class QuartzContext:
    cdef Context *context
    cdef EquivalenceSet *eqs
    cdef vector[GraphXfer *] v_xfers
    cdef bool include_nop

    def __cinit__(self, *,  gate_set, filename, no_increase=False, include_nop=True):
        gate_type_list = []
        for s in gate_set:
            gate_type_list.append(get_gate_type_from_str(s))
        if GateType.input_param not in gate_type_list:
            gate_type_list.append(GateType.input_param)
        if GateType.input_qubit not in gate_type_list:
            gate_type_list.append(GateType.input_qubit)
        self.context = new Context(gate_type_list)
        self.eqs = new EquivalenceSet()
        self.load_json(filename)

        eq_sets = self.eqs.get_all_equivalence_sets()

        # for i in range(eq_sets.size()):
        #     for j in range(eq_sets[i].size()):
        #         if j != 0:
        #             dag_ptr_0 = eq_sets[i][0]
        #             dag_ptr_1 = eq_sets[i][j]
        #             xfer_0 = GraphXfer.create_GraphXfer(self.context, dag_ptr_0, dag_ptr_1, no_increase)
        #             xfer_1 = GraphXfer.create_GraphXfer(self.context, dag_ptr_1, dag_ptr_0, no_increase)
        #             if xfer_0 != NULL:
        #                 self.v_xfers.push_back(xfer_0)
        #             if xfer_1 != NULL:
        #                 self.v_xfers.push_back(xfer_1)

        # for i in range(eq_sets.size()):
        #     for j in range(eq_sets[i].size()):
        #         if j != 0:
        #             dag_ptr_0 = eq_sets[i][0]
        #             dag_ptr_1 = eq_sets[i][j]
        #             xfer_0 = GraphXfer.create_GraphXfer(self.context, dag_ptr_0, dag_ptr_1, no_increase)
        #             xfer_1 = GraphXfer.create_GraphXfer(self.context, dag_ptr_1, dag_ptr_0, no_increase)
        #             if xfer_0 != NULL and xfer_0.num_dst_op() - xfer_0.num_src_op() < 2:
        #                 self.v_xfers.push_back(xfer_0)
        #             if xfer_1 != NULL and xfer_1.num_dst_op() - xfer_1.num_src_op() < 2:
        #                 self.v_xfers.push_back(xfer_1)

        for i in range(eq_sets.size()):
            for j in range(eq_sets[i].size()):
                for k in range(eq_sets[i].size()):
                    if j != k:
                        dag_ptr_0 = eq_sets[i][j]
                        dag_ptr_1 = eq_sets[i][k]
                        xfer = GraphXfer.create_GraphXfer(self.context, dag_ptr_0, dag_ptr_1, no_increase)
                        if xfer != NULL:
                            self.v_xfers.push_back(xfer)
        self.include_nop = include_nop

    cdef load_json(self, filename):
        # Load ECC from file
        filename_bytes = filename.encode('utf-8')
        assert(self.eqs.load_json(self.context, filename_bytes), "Failed to load equivalence set.")

    # size_t next_global_unique_id();
    def next_global_unique_id(self):
        return self.context.next_global_unique_id()

    def get_xfers(self):
        # Get all the equivalence sets
        # And convert them into xfers
        num_xfers = self.v_xfers.size()

        xfers = []
        for i in range(num_xfers):
            xfers.append(PyXfer().set_this(self.v_xfers[i]))
        if self.include_nop:
            xfers.append(PyXfer(is_nop=True))
        return xfers

    def get_xfer_from_id(self, *, id) -> PyXfer:
        if id < self.v_xfers.size():
            xfer = PyXfer().set_this(self.v_xfers[id])
        elif self.include_nop and id == self.v_xfers.size():
            xfer = PyXfer(is_nop=True)
        else:
            xfer = None
        return xfer

    def xfer_id_is_nop(self, *, xfer_id) -> bool:
        if xfer_id == self.v_xfers.size():
            if self.include_nop:
                return True
            else:
                assert False
        else:
            return False

    def has_parameterized_gate(self) -> bool:
        return self.context.has_parameterized_gate()

    @property
    def num_equivalence_classes(self):
        return self.eqs.num_equivalence_classes()

    @property
    def num_xfers(self):
        num = self.v_xfers.size()
        if self.include_nop:
            num += 1
        return num

from functools import partial

cdef class PyNode:
    cdef Op node

    def __cinit__(self, *, int guid = -1, PyGate gate = None):
        if id != -1 and gate != None:
            self.node = Op(guid, gate.gate)
        else:
            self.node = Op()

    def __dealloc__(self):
        pass

    @property
    def node_guid(self):
        return self.node.guid

    @property
    def guid(self):
        return self.node.guid

    @property
    def gate(self):
        return PyGate().set_this(self.node.ptr)

    @property
    def gate_tp(self):
        return self.node.ptr.tp

    def __reduce__(self):
        return (
            partial(self.__class__, guid=self.node_guid, gate=self.gate), ()
        )

cdef class PyGraph:
    cdef shared_ptr[Graph] graph
    cdef object _nodes

    property nodes:
        def __get__(self):
            return self._nodes

        def __set__(self, nodes):
            self._nodes = nodes

    def __cinit__(self, *, QuartzContext context = None, PyDAG dag = None):
        self.nodes = []
        if context != None and dag != None:
            self.graph = make_shared[Graph](context.context, dag.dag)
            self.get_nodes()
        else:
            self.graph = shared_ptr[Graph](NULL)

    def __dealloc__(self):
        self.graph.reset()

    def __hash__(self):
        return deref(self.graph).hash()

    def get_nodes(self):
        gate_count = self.gate_count
        cdef vector[Op] nodes_vec
        nodes_vec.reserve(gate_count)
        deref(self.graph).topology_order_ops(nodes_vec)

        self.nodes = []
        for i in range(gate_count):
            self.nodes.append(PyNode(
                guid=nodes_vec[i].guid,
                gate=PyGate().set_this(nodes_vec[i].ptr)
            ))

    cdef set_this(self, shared_ptr[Graph] graph_):
        self.graph = graph_
        self.get_nodes()
        return self

    # TODO: deprecate this function
    cdef _xfer_appliable(self, PyXfer xfer, PyNode node):
        return deref(self.graph).xfer_appliable(xfer.graphXfer, node.node)

    # TODO: use node_id directly instead of using PyNode
    def xfer_appliable(self, *, PyXfer xfer, PyNode node):
        if xfer.is_nop:
            return True
        return self._xfer_appliable(xfer, node)

    # TODO: use node_id directly instead of using PyNode
    def available_xfers(self, *, QuartzContext context, PyNode node, output_format="int"):
        result = deref(self.graph).appliable_xfers(node.node, context.v_xfers)
        if context.include_nop:
            result.push_back(context.num_xfers - 1)
        return result

    def available_xfers_parallel(self, *, QuartzContext context, PyNode node, output_format="int"):
        result = deref(self.graph).appliable_xfers_parallel(node.node, context.v_xfers)
        if context.include_nop:
            result.push_back(context.num_xfers - 1)
        return result

    # TODO: use node_id directly instead of using PyNode
    def apply_xfer(self, *, PyXfer xfer, PyNode node, eliminate_rotation:bool = False) -> PyGraph:
        if xfer.is_nop:
            return self
        ret = deref(self.graph).apply_xfer(xfer.graphXfer, node.node, eliminate_rotation)
        if ret.get() == NULL:
            return None
        else:
            return PyGraph().set_this(ret)

    # TODO: use node_id directly instead of using PyNode
    def apply_xfer_with_local_state_tracking(self, *, PyXfer xfer, PyNode node, eliminate_rotation:bool = False):
        if xfer.is_nop:
            return self, []
        ret = deref(self.graph).apply_xfer_and_track_node(xfer.graphXfer, node.node, eliminate_rotation)
        if ret.first.get() == NULL:
            return None, []
        else:
            return PyGraph().set_this(ret.first), ret.second

    def all_nodes(self):
        return self.nodes

    def all_nodes_with_id(self) -> list:
        nodes_with_id = [
            { "id": i, 'node': node }
            for (i, node) in enumerate(self.nodes)
        ]
        return nodes_with_id

    def get_node_from_id(self, *, id : int) -> PyNode:
        n = self.num_nodes
        if id >= n:
            print(id)
            print(n)
            self.to_qasm(filename='a.qasm')
        assert(id < self.num_nodes)
        return self.nodes[id]

    def hash(self):
        return deref(self.graph).hash()

    def all_edges(self):
        id_guid_mapping = {}
        gate_cnt = len(self.nodes)
        for i in range(gate_cnt):
            id_guid_mapping[self.nodes[i].guid] = i

        cdef vector[Edge] edge_v
        deref(self.graph).all_edges(edge_v)
        cdef int edge_cnt = edge_v.size()
        edges = []
        for i in range(edge_cnt):
            e = (id_guid_mapping[edge_v[i].srcOp.guid], id_guid_mapping[edge_v[i].dstOp.guid], edge_v[i].srcIdx, edge_v[i].dstIdx)
            edges.append(e)
        return edges

    def to_dgl_graph(self):
        edges = self.all_edges()
        src_id = []
        dst_id = []
        src_idx = []
        dst_idx = []

        for e in edges:
            src_id.append(e[0])
            dst_id.append(e[1])
            src_idx.append(e[2])
            dst_idx.append(e[3])
        src_id2 = src_id + dst_id
        dst_id2 = dst_id + src_id
        src_idx2 = src_idx + dst_idx
        dst_idx2 = dst_idx + src_idx
        reverse = [0] * len(src_id) + [1] * len(src_id)

        g = dgl.graph((torch.tensor(src_id2, dtype=torch.int32),
                       torch.tensor(dst_id2, dtype=torch.int32)))
        g.edata['src_idx'] = torch.tensor(src_idx2, dtype=torch.int32)
        g.edata['dst_idx'] = torch.tensor(dst_idx2, dtype=torch.int32)
        g.edata['reversed'] = torch.tensor(reverse, dtype=torch.int32)

        node_gate_tp = [node.gate_tp for node in self.nodes]
        g.ndata['gate_type'] = torch.tensor(node_gate_tp, dtype=torch.int32)

        return g

    def get_available_xfers_matrix(self, *, context):
        rows, cols = (self.num_nodes, context.num_xfers)
        arr = [[0 for i in range(cols)] for j in range(rows)]
        for i in range(rows):
            available_list = self.available_xfers(context=context, node=self.nodes[i], output_format='int')
            for xfer_id in available_list:
                arr[i][xfer_id] = 1
        return arr

    # def toffoli_flip(self, *, QuartzContext context, str target):
    #     if target == "t":
    #         return PyGraph().set_this(deref(self.graph).ccz_flip_t(context.context))
    #     return None

    def to_qasm(self, *, str filename):
        fn_bytes = filename.encode('utf-8')
        deref(self.graph).to_qasm(fn_bytes, False, False)

    def to_qasm_str(self, *) -> str:
        cdef string s = deref(self.graph).to_qasm(False, False)
        return s.decode('utf-8')

    def rotation_merging(self, gate_type:str):
        deref(self.graph).rotation_merging(get_gate_type_from_str(gate_type))
        self.get_nodes()
        return self

    @staticmethod
    def from_qasm(*, context : QuartzContext, filename : str):
        filename_bytes = filename.encode('utf-8')
        return PyGraph().set_this(Graph.from_qasm_file(context.context, filename_bytes))

    @staticmethod
    def from_qasm_str(*, context : QuartzContext, qasm_str : str):
        qasm_str_bytes = qasm_str.encode('utf-8')
        return PyGraph().set_this(Graph.from_qasm_str(context.context, qasm_str_bytes))

    def ccz_flip_greedy_rz(self, *, rotation_merging=False):
        return PyGraph().set_this(deref(self.graph).ccz_flip_greedy_rz())

    def __lt__(self, other):
        return self.gate_count < other.gate_count

    def __le__(self, other):
        return self.gate_count <= other.gate_count

    @property
    def gate_count(self):
        return deref(self.graph).gate_count()

    @property
    def cx_count(self):
        return deref(self.graph).specific_gate_count(GateType.cx)

    @property
    def t_count(self):
        return deref(self.graph).specific_gate_count(GateType.t) + deref(self.graph).specific_gate_count(GateType.tdg)

    @property
    def num_nodes(self):
        return len(self.nodes)

    @property
    def num_edges(self):
        cdef vector[Edge] edge_v
        deref(self.graph).all_edges(edge_v)
        return edge_v.size()


# physical mapping related
def ToBackendType(tp_str: str) -> BackendType:
    if tp_str == "Q20_CLIQUE":
        return BackendType.Q20_CLIQUE
    elif tp_str == "IBM_Q20_TOKYO":
        return BackendType.IBM_Q20_TOKYO
    elif tp_str == "Q5_TEST":
        return BackendType.Q5_TEST
    elif tp_str == "IBM_Q127_EAGLE":
        return BackendType.IBM_Q127_EAGLE
    elif tp_str == "IBM_Q27_FALCON":
        return BackendType.IBM_Q27_FALCON
    elif tp_str == "IBM_Q65_HUMMINGBIRD":
        return BackendType.IBM_Q65_HUMMINGBIRD
    else:
        raise NotImplementedError

def FromBackendType(tp: BackendType) -> str:
    if tp == BackendType.Q20_CLIQUE:
        return "Q20_CLIQUE"
    elif tp == BackendType.IBM_Q20_TOKYO:
        return "IBM_Q20_TOKYO"
    elif tp == BackendType.Q5_TEST:
        return "Q5_TEST"
    elif tp == BackendType.IBM_Q127_EAGLE:
        return "IBM_Q127_EAGLE"
    elif tp == BackendType.IBM_Q27_FALCON:
        return "IBM_Q27_FALCON"
    elif tp == BackendType.IBM_Q65_HUMMINGBIRD:
        return "IBM_Q65_HUMMINGBIRD"
    else:
        raise NotImplementedError

def ToActionType(tp_str: str) -> ActionType:
    if tp_str == "PhysicalFull":
        return ActionType.PhysicalFull
    elif tp_str == "PhysicalFront":
        return ActionType.PhysicalFront
    elif tp_str == "Logical":
        return ActionType.Logical
    elif tp_str == "SearchFull":
        return ActionType.SearchFull
    elif tp_str == "Unknown":
        return ActionType.Unknown
    else:
        raise NotImplementedError

def FromActionType(tp: ActionType) -> str:
    if tp == ActionType.PhysicalFull:
        return "PhysicalFull"
    elif tp == ActionType.PhysicalFront:
        return "PhysicalFront"
    elif tp == ActionType.Logical:
        return "Logical"
    elif tp == ActionType.SearchFull:
        return "SearchFull"
    elif tp == ActionType.Unknown:
        return "Unknown"
    else:
        raise NotImplementedError

cdef class PyAction:
    cdef shared_ptr[Action] action_ptr

    def __cinit__(self, *, type_str="Unknown", qubit_idx_0=-1, qubit_idx_1=-1, instantiate=True):
        cdef ActionType cur_tp = ToActionType(str(type_str))
        cdef int cur_idx_0 = qubit_idx_0
        cdef int cur_idx_1 = qubit_idx_1
        if instantiate:
            self.action_ptr = make_shared[Action](cur_tp, cur_idx_0, cur_idx_1)
        else:
            pass

    def __dealloc__(self):
        pass

    cdef set_this(self, shared_ptr[Action] _action_ptr):
        self.action_ptr = _action_ptr

    @property
    def qubit_idx_0(self) -> int:
        return deref(self.action_ptr).qubit_idx_0

    @property
    def qubit_idx_1(self) -> int:
        return deref(self.action_ptr).qubit_idx_1

    @property
    def type(self) -> str:
        return FromActionType(deref(self.action_ptr).type)

class PyDevice:
    def __init__(self):
        self.edge_list = []

    def add_edge(self, reg_idx_0: int, reg_idx_1: int):
        self.edge_list.append([reg_idx_0, reg_idx_1])

class PyMappingTable:
    def __init__(self):
        self.map = {}

    def add_mapping(self, from_idx: int, to_idx: int):
        assert from_idx not in self.map
        self.map[from_idx] = to_idx

class PyGraphState:
    def __init__(self):
        self.number_of_nodes = 0
        self.node_id = []
        self.is_input = []
        self.input_logical_idx = []
        self.input_physical_idx = []
        self.node_type = []
        self.number_of_edges = 0
        self.edge_from = []
        self.edge_to = []
        self.edge_reversed = []
        self.edge_logical_idx = []
        self.edge_physical_idx = []

cdef class PyState:
    cdef shared_ptr[State] state_ptr
    cdef object graph_state
    cdef object device_edges
    cdef object logical2physical
    cdef object physical2logical
    cdef object is_initial_phase

    def __init__(self):
        self.graph_state = None         # PyGraphState
        self.device_edges = None        # PyDevice
        self.logical2physical = None    # PyMappingTable
        self.physical2logical = None    # PyMappingTable
        self.is_initial_phase = None    # bool

    def __cinit__(self, *):
        pass

    def __dealloc__(self):
        pass

    cdef set_this(self, shared_ptr[State] _state_ptr):
        # set state ptr, this is original date from c side
        self.state_ptr = _state_ptr

        # extract data: graph
        cdef GraphState c_graph_state = deref(_state_ptr).graph_state
        py_graph_state = PyGraphState()
        py_graph_state.number_of_nodes = c_graph_state.number_of_nodes
        for i in range(py_graph_state.number_of_nodes):
            py_graph_state.node_id.append(c_graph_state.node_id[i])
            py_graph_state.is_input.append(c_graph_state.is_input[i])
            py_graph_state.input_logical_idx.append(c_graph_state.input_logical_idx[i])
            py_graph_state.input_physical_idx.append(c_graph_state.input_physical_idx[i])
            py_graph_state.node_type.append(c_graph_state.node_type[i])
        py_graph_state.number_of_edges = c_graph_state.number_of_edges
        for i in range(py_graph_state.number_of_edges):
            py_graph_state.edge_from.append(c_graph_state.edge_from[i])
            py_graph_state.edge_to.append(c_graph_state.edge_to[i])
            py_graph_state.edge_reversed.append(c_graph_state.edge_reversed[i])
            py_graph_state.edge_logical_idx.append(c_graph_state.edge_logical_idx[i])
            py_graph_state.edge_physical_idx.append(c_graph_state.edge_physical_idx[i])
        self.graph_state = py_graph_state

        # extract data: device edges
        cdef vector[pair[int, int]] c_device_edges = deref(_state_ptr).device_edges
        cdef int edge_count = c_device_edges.size()
        self.device_edges = PyDevice()
        for i in range(edge_count):
            self.device_edges.add_edge(c_device_edges[i].first, c_device_edges[i].second)

        # extract data: mapping table
        cdef vector[int] c_logical2physical = deref(_state_ptr).logical2physical
        cdef int num_qubits = c_logical2physical.size()
        self.logical2physical = PyMappingTable()
        for i in range(num_qubits):
            self.logical2physical.add_mapping(i, c_logical2physical[i])
        cdef vector[int] c_physical2logical = deref(_state_ptr).physical2logical
        cdef int num_regs =  c_physical2logical.size()
        self.physical2logical = PyMappingTable()
        for i in range(num_regs):
            self.physical2logical.add_mapping(i, c_physical2logical[i])
        assert num_regs == num_qubits

        # set initial phase status
        self.is_initial_phase = deref(_state_ptr).is_initial_phase

    @property
    def circuit(self) -> PyGraphState:
        return self.graph_state

    def get_circuit_dgl(self):
        g = dgl.graph((torch.tensor(self.graph_state.edge_from, dtype=torch.int32),
                       torch.tensor(self.graph_state.edge_to, dtype=torch.int32)))
        g.edata['logical_idx'] = torch.tensor(self.graph_state.edge_logical_idx, dtype=torch.int32)
        g.edata['physical_idx'] = torch.tensor(self.graph_state.edge_physical_idx, dtype=torch.int32)
        g.edata['reversed'] = torch.tensor(self.graph_state.edge_reversed, dtype=torch.int32)
        g.ndata['is_input'] = torch.tensor(self.graph_state.is_input, dtype=torch.int32)
        return g

    @property
    def device_edges_list(self) -> [[int, int]]:
        return self.device_edges.edge_list

    def get_device_dgl(self):
        # pack device edges into tensor and gather degree as node feature
        src_id = []
        dst_id = []
        node_degree = [0] * len(self.physical2logical.map)
        node_id = list(range(len(self.physical2logical.map)))
        for edge in self.device_edges.edge_list:
            assert len(edge) == 2
            src_id.append(edge[0])
            dst_id.append(edge[1])
            node_degree[edge[0]] += 1

        # create dgl graph
        dgl_graph = dgl.graph((torch.tensor(src_id, dtype=torch.int32),
                               torch.tensor(dst_id, dtype=torch.int32)))
        dgl_graph.ndata['degree'] = torch.tensor(node_degree, dtype=torch.int32)
        dgl_graph.ndata['id'] = torch.tensor(node_id, dtype=torch.int32)
        return dgl_graph

    @property
    def logical2physical_mapping(self) -> {int: int}:
        return self.logical2physical.map

    @property
    def physical2logical_mapping(self) -> {int: int}:
        return self.physical2logical.map

    @property
    def is_initial_phase(self) -> bool:
        return self.is_initial_phase


cdef class PySimplePhysicalEnv:
    cdef SimplePhysicalEnv *env

    def __cinit__(self, *, qasm_file_path: str, backend_type_str: str,
                  seed: int, start_from_internal_prob: float, initial_mapping_file_path: str):
        cdef string encoded_path = qasm_file_path.encode('utf-8')
        cdef BackendType cur_backend_type = ToBackendType(backend_type_str)
        cdef string encoded_initial_mapping_path = initial_mapping_file_path.encode('utf-8')
        self.env = new SimplePhysicalEnv(encoded_path, cur_backend_type, seed,
                                         start_from_internal_prob, encoded_initial_mapping_path)

    def __dealloc__(self):
        del self.env

    def reset(self):
        self.env.reset()

    def step(self, PyAction action) -> Reward:
        return self.env.step(deref(action.action_ptr))

    def step_with_id(self, qubit_idx_0: int, qubit_idx_1: int) -> Reward:
        cdef int _qubit_idx_0 = qubit_idx_0
        cdef int _qubit_idx_1 = qubit_idx_1
        cdef shared_ptr[Action] action = make_shared[Action](ActionType.PhysicalFront,
                                                             _qubit_idx_0,
                                                             _qubit_idx_1)
        return self.env.step(deref(action))

    def is_finished(self) -> bool:
        return self.env.is_finished()

    def total_cost(self) -> int:
        return self.env.total_cost()

    def get_state(self) -> PyState:
        cdef shared_ptr[State] c_state = make_shared[State](self.env.get_state())
        py_state = PyState()
        py_state.set_this(c_state)
        return py_state

    def get_action_space(self) -> [PyAction]:
        cdef vector[Action] c_action_space = self.env.get_action_space()
        cdef shared_ptr[Action] tmp_c_action
        total_size = c_action_space.size()
        py_action_space = []
        for i in range(total_size):
            tmp_c_action = make_shared[Action](c_action_space[i])
            py_action = PyAction(instantiate=False)
            py_action.set_this(tmp_c_action)
            py_action_space.append(py_action)
        return py_action_space


cdef class PySimpleInitialEnv:
    cdef SimpleInitialEnv *env

    def __cinit__(self, *, qasm_file_path: str, backend_type_str: str):
        cdef string encoded_path = qasm_file_path.encode('utf-8')
        cdef BackendType cur_backend_type = ToBackendType(backend_type_str)
        self.env = new SimpleInitialEnv(encoded_path, cur_backend_type)

    def __dealloc__(self):
        del self.env

    def reset(self):
        self.env.reset()

    def step(self, PyAction action) -> Reward:
        return self.env.step(deref(action.action_ptr))

    def step_with_id(self, qubit_idx_0: int, qubit_idx_1: int) -> Reward:
        cdef int _qubit_idx_0 = qubit_idx_0
        cdef int _qubit_idx_1 = qubit_idx_1
        cdef shared_ptr[Action] action = make_shared[Action](ActionType.PhysicalFull,
                                                             _qubit_idx_0,
                                                             _qubit_idx_1)
        return self.env.step(deref(action))

    def get_state(self) -> PyState:
        cdef shared_ptr[State] c_state = make_shared[State](self.env.get_state())
        py_state = PyState()
        py_state.set_this(c_state)
        return py_state

    def get_action_space(self) -> [PyAction]:
        cdef vector[Action] c_action_space = self.env.get_action_space()
        cdef shared_ptr[Action] tmp_c_action
        total_size = c_action_space.size()
        py_action_space = []
        for i in range(total_size):
            tmp_c_action = make_shared[Action](c_action_space[i])
            py_action = PyAction(instantiate=False)
            py_action.set_this(tmp_c_action)
            py_action_space.append(py_action)
        return py_action_space

cdef class PySimpleSearchEnv:
    cdef shared_ptr[SimpleSearchEnv] env

    def __cinit__(self, *, qasm_file_path: str, backend_type_str: str,
                  seed: int, start_from_internal_prob: float, initial_mapping_file_path: str,
                  instantiate=True):
        if not instantiate:
            return
        cdef string encoded_path = qasm_file_path.encode('utf-8')
        cdef BackendType cur_backend_type = ToBackendType(backend_type_str)
        cdef int c_seed = seed
        cdef double c_start_from_internal_prob = start_from_internal_prob
        cdef string encoded_initial_mapping_path = initial_mapping_file_path.encode('utf-8')
        self.env = make_shared[SimpleSearchEnv](encoded_path, cur_backend_type, c_seed,
                                                c_start_from_internal_prob, encoded_initial_mapping_path)

    def __dealloc__(self):
        pass

    def reset(self):
        deref(self.env).reset()

    def step(self, PyAction action) -> Reward:
        return deref(self.env).step(deref(action.action_ptr))

    def step_with_id(self, qubit_idx_0: int, qubit_idx_1: int) -> Reward:
        cdef int _qubit_idx_0 = qubit_idx_0
        cdef int _qubit_idx_1 = qubit_idx_1
        cdef shared_ptr[Action] action = make_shared[Action](ActionType.SearchFull,
                                                             _qubit_idx_0,
                                                             _qubit_idx_1)
        return deref(self.env).step(deref(action))

    def get_state(self) -> PyState:
        cdef shared_ptr[State] c_state = make_shared[State](deref(self.env).get_state())
        py_state = PyState()
        py_state.set_this(c_state)
        return py_state

    def get_action_space(self) -> [PyAction]:
        cdef vector[Action] c_action_space = deref(self.env).get_action_space()
        cdef shared_ptr[Action] tmp_c_action
        total_size = c_action_space.size()
        py_action_space = []
        for i in range(total_size):
            tmp_c_action = make_shared[Action](c_action_space[i])
            py_action = PyAction(instantiate=False)
            py_action.set_this(tmp_c_action)
            py_action_space.append(py_action)
        return py_action_space

    def copy(self) -> PySimpleSearchEnv:
        cdef shared_ptr[SimpleSearchEnv] copied_c_env = deref(self.env).copy()
        copied_py_env = PySimpleSearchEnv(qasm_file_path="", backend_type_str="",
                                          seed=-1, start_from_internal_prob=-1,
                                          initial_mapping_file_path="",
                                          instantiate=False)
        copied_py_env.env = copied_c_env
        return copied_py_env

cdef class PySimpleHybridEnv:
    cdef SimpleHybridEnv *env

    def __cinit__(self, *,
                  # basic parameters
                  qasm_file_path: str, backend_type_str: str, initial_mapping_file_path: str,
                  # randomness and buffer
                  seed: int, start_from_internal_prob: float,
                  # GameHybrid
                  initial_phase_len: int, allow_nop_in_initial: bool, initial_phase_reward: double):
        cdef string encoded_path = qasm_file_path.encode('utf-8')
        cdef BackendType cur_backend_type = ToBackendType(backend_type_str)
        cdef string encoded_initial_mapping_path = initial_mapping_file_path.encode('utf-8')
        self.env = new SimpleHybridEnv(encoded_path, cur_backend_type, encoded_initial_mapping_path,
                                       seed, start_from_internal_prob,
                                       initial_phase_len, allow_nop_in_initial, initial_phase_reward)

    def __dealloc__(self):
        del self.env

    def reset(self):
        self.env.reset()

    def step(self, PyAction action) -> Reward:
        return self.env.step(deref(action.action_ptr))

    def step_with_id(self, qubit_idx_0: int, qubit_idx_1: int) -> Reward:
        # determine action type
        cdef vector[Action] c_action_space = self.env.get_action_space()
        cdef ActionType action_type = c_action_space[0].type

        # construct action and apply
        cdef int _qubit_idx_0 = qubit_idx_0
        cdef int _qubit_idx_1 = qubit_idx_1
        cdef shared_ptr[Action] action = make_shared[Action](action_type,
                                                             _qubit_idx_0,
                                                             _qubit_idx_1)
        return self.env.step(deref(action))

    def is_finished(self) -> bool:
        return self.env.is_finished()

    def total_cost(self) -> int:
        return self.env.total_cost()

    def get_state(self) -> PyState:
        cdef shared_ptr[State] c_state = make_shared[State](self.env.get_state())
        py_state = PyState()
        py_state.set_this(c_state)
        return py_state

    def get_action_space(self) -> [PyAction]:
        cdef vector[Action] c_action_space = self.env.get_action_space()
        cdef shared_ptr[Action] tmp_c_action
        total_size = c_action_space.size()
        py_action_space = []
        for i in range(total_size):
            tmp_c_action = make_shared[Action](c_action_space[i])
            py_action = PyAction(instantiate=False)
            py_action.set_this(tmp_c_action)
            py_action_space.append(py_action)
        return py_action_space

    def save_context(self,
                     execution_history_file_path: str,
                     single_qubit_gate_execution_plan_file_path: str,
                     ) -> bool:
        # parse input (must be at the beginning)
        cdef string encoded_execution_history_file_path = execution_history_file_path.encode('utf-8')
        cdef string encoded_single_qubit_gate_execution_plan_file_path = single_qubit_gate_execution_plan_file_path.encode('utf-8')

        # return true if env is finished and saved, o.w. return false
        if self.is_finished():
            self.env.save_context_to_file(encoded_execution_history_file_path,
                                          encoded_single_qubit_gate_execution_plan_file_path)
            return True
        else:
            return False

    def generate_mapped_qasm(self, mapped_qasm_file_path: str, debug_mode: bool) -> bool:
        # parse input (must be at the beginning)
        cdef string encoded_mapped_qasm_file_path = mapped_qasm_file_path.encode('utf-8')

        # return true if env is finished and saved, o.w. return false
        if self.is_finished():
            self.env.generate_mapped_qasm(encoded_mapped_qasm_file_path, debug_mode)
            return True
        else:
            return False

