clear; clc; close all

syms s k
num = sym(1);
den = expand((s+2)*(s+4)*(s+6));
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));


rlocus(g)
grid
zeta = abs(log(0.1)/sqrt(pi^2+log(0.1)^2))
sgrid(zeta,[]) % k ~ 45.5281


k = solve(RouthArray(3,1)) % K or K^2 = 480
crovrPt = double(solve(den+k*num))


k = 45.5281;
num_tf = sym(k);
den_tf = expand((s+2)*(s+4)*(s+6)+k);

g_tf = tf(sym2poly(num_tf),sym2poly(den_tf));
pole(g_tf)
stepinfo(g_tf)
figure
step(g_tf)