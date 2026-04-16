clear; clc; close all

syms s k
num = expand((s+2.5)*(s+3.2));
zeros = solve(num)
den = expand(s^2*(s+1)*(s+10)*(s+30));
poles = solve(den)
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));

rlocus(g)
grid
xlim([-35,5])
ylim([-40,40])

tempK = solve(RouthArray(3,1))
tempK = solve(RouthArray(4,1))
tempK = solve(RouthArray(5,1))

k = solve(RouthArray(5,1)); % [559.35226621708740657384781754683, 4320.9126460636143478121170947339]
for n = 1:2;
    poles_k{n} = double(solve(den+k(n+1)*num));
end