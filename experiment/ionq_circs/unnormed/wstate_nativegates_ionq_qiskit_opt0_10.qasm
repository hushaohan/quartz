// Benchmark was created by MQT Bench on 2022-08-31
// For more information about MQT Bench, please visit https://www.cda.cit.tum.de/mqtbench/
// MQT Bench version: 0.1.0
// Qiskit version: {'qiskit-terra': '0.20.0', 'qiskit-aer': '0.10.4', 'qiskit-ignis': '0.7.0', 'qiskit-ibmq-provider': '0.19.0', 'qiskit-aqua': None, 'qiskit': '0.36.0', 'qiskit-nature': '0.3.1', 'qiskit-finance': '0.3.1', 'qiskit-optimization': '0.3.2', 'qiskit-machine-learning': '0.4.0'}
// Used Gate Set: ['rxx', 'rz', 'ry', 'rx', 'measure']

OPENQASM 2.0;
include "qelib1.inc";
qreg q[10];
creg meas[10];
ry(-pi/4) q[0];
ry(pi/2) q[0];
rx(pi) q[0];
ry(-0.95531662) q[1];
ry(pi/2) q[1];
rx(pi) q[1];
ry(-pi/3) q[2];
ry(pi/2) q[2];
rx(pi) q[2];
ry(-1.1071487) q[3];
ry(pi/2) q[3];
rx(pi) q[3];
ry(-1.150262) q[4];
ry(pi/2) q[4];
rx(pi) q[4];
ry(-1.1831996) q[5];
ry(pi/2) q[5];
rx(pi) q[5];
ry(-1.2094292) q[6];
ry(pi/2) q[6];
rx(pi) q[6];
ry(-1.2309594) q[7];
ry(pi/2) q[7];
rx(pi) q[7];
ry(-1.2490458) q[8];
ry(pi/2) q[8];
rx(pi) q[8];
rx(pi) q[9];
ry(pi/2) q[9];
rxx(pi/2) q[9],q[8];
rx(-pi/2) q[8];
ry(pi/2) q[8];
rx(pi) q[8];
ry(1.2490458) q[8];
ry(pi/2) q[8];
rxx(pi/2) q[8],q[7];
rx(-pi/2) q[7];
ry(pi/2) q[7];
rx(pi) q[7];
ry(1.2309594) q[7];
ry(pi/2) q[7];
rxx(pi/2) q[7],q[6];
rx(-pi/2) q[6];
ry(pi/2) q[6];
rx(pi) q[6];
ry(1.2094292) q[6];
ry(pi/2) q[6];
rxx(pi/2) q[6],q[5];
rx(-pi/2) q[5];
ry(pi/2) q[5];
rx(pi) q[5];
ry(1.1831996) q[5];
ry(pi/2) q[5];
rxx(pi/2) q[5],q[4];
rx(-pi/2) q[4];
ry(pi/2) q[4];
rx(pi) q[4];
ry(1.150262) q[4];
ry(pi/2) q[4];
rxx(pi/2) q[4],q[3];
rx(-pi/2) q[3];
ry(pi/2) q[3];
rx(pi) q[3];
ry(1.1071487) q[3];
ry(pi/2) q[3];
rxx(pi/2) q[3],q[2];
rx(-pi/2) q[2];
ry(pi/2) q[2];
rx(pi) q[2];
ry(pi/3) q[2];
ry(pi/2) q[2];
rxx(pi/2) q[2],q[1];
rx(-pi/2) q[1];
ry(pi/2) q[1];
rx(pi) q[1];
ry(0.95531662) q[1];
ry(pi/2) q[1];
rxx(pi/2) q[1],q[0];
rx(-pi/2) q[0];
ry(pi/2) q[0];
rx(pi) q[0];
ry(pi/4) q[0];
ry(pi/2) q[0];
rx(-pi/2) q[1];
ry(-pi/2) q[1];
ry(pi/2) q[1];
rx(-pi/2) q[2];
ry(-pi/2) q[2];
ry(pi/2) q[2];
rx(-pi/2) q[3];
ry(-pi/2) q[3];
ry(pi/2) q[3];
rx(-pi/2) q[4];
ry(-pi/2) q[4];
ry(pi/2) q[4];
rx(-pi/2) q[5];
ry(-pi/2) q[5];
ry(pi/2) q[5];
rx(-pi/2) q[6];
ry(-pi/2) q[6];
ry(pi/2) q[6];
rx(-pi/2) q[7];
ry(-pi/2) q[7];
ry(pi/2) q[7];
rx(-pi/2) q[8];
ry(-pi/2) q[8];
ry(pi/2) q[8];
rx(-pi/2) q[9];
ry(-pi/2) q[9];
rxx(pi/2) q[8],q[9];
rx(-pi/2) q[8];
ry(-pi/2) q[8];
rxx(pi/2) q[7],q[8];
rx(-pi/2) q[7];
ry(-pi/2) q[7];
rxx(pi/2) q[6],q[7];
rx(-pi/2) q[6];
ry(-pi/2) q[6];
rxx(pi/2) q[5],q[6];
rx(-pi/2) q[5];
ry(-pi/2) q[5];
rxx(pi/2) q[4],q[5];
rx(-pi/2) q[4];
ry(-pi/2) q[4];
rxx(pi/2) q[3],q[4];
rx(-pi/2) q[3];
ry(-pi/2) q[3];
rxx(pi/2) q[2],q[3];
rx(-pi/2) q[2];
ry(-pi/2) q[2];
rxx(pi/2) q[1],q[2];
rx(-pi/2) q[1];
ry(-pi/2) q[1];
rxx(pi/2) q[0],q[1];
rx(-pi/2) q[0];
ry(-pi/2) q[0];
rx(-pi/2) q[1];
rx(-pi/2) q[2];
rx(-pi/2) q[3];
rx(-pi/2) q[4];
rx(-pi/2) q[5];
rx(-pi/2) q[6];
rx(-pi/2) q[7];
rx(-pi/2) q[8];
rx(-pi/2) q[9];
barrier q[0],q[1],q[2],q[3],q[4],q[5],q[6],q[7],q[8],q[9];
measure q[0] -> meas[0];
measure q[1] -> meas[1];
measure q[2] -> meas[2];
measure q[3] -> meas[3];
measure q[4] -> meas[4];
measure q[5] -> meas[5];
measure q[6] -> meas[6];
measure q[7] -> meas[7];
measure q[8] -> meas[8];
measure q[9] -> meas[9];
