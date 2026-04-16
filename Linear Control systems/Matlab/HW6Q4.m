clear; clc; close all

syms s k
num = sym(s^2+7*s+20);
zeros = solve(num)
den = expand(s*(s+2)*(s+5));
poles = solve(den)
bkwyEq = simplify(diff(-den/num))
bkwyPt = double(solve(bkwyEq))
CharEq = simplify(den+k*num)
CharEqCoeff = fliplr(coeffs(CharEq,s));
RouthArray = simplify(routh_hurwitz(CharEqCoeff))

g = tf(sym2poly(num),sym2poly(den));

rlocus(g)
grid
zeta = abs(log(0.05)/sqrt(pi^2+log(0.05)^2));
sgrid(zeta,[]) % k ~ 14.2545
hold on
xline(-1.6,'LineStyle',':','Label','-1.6','LabelOrientation','horizontal','LabelVerticalAlignment','bottom','LabelHorizontalAlignment','center')

figure
hold on
for k = [0,0.1,1,10,100,1000]
    num_cf = sym(10*(s+k));
    den_cf = simplify(den+k*num);
    g_cl = tf(sym2poly(num_cf),sym2poly(den_cf));
    step(g_cl)
end
legend('K = 0','K = 0.1','K = 1','K = 10','K = 100','K = 1000')