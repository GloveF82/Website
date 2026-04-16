clear; clc; close all

syms s k
var = s;
k = 100;
num_ol = sym(k*(var^2-4*var+13));
den_ol = expand((var+2)*(var+4)*(var));
g_ol = tf(sym2poly(num_ol),sym2poly(den_ol));

syms w real
var = 1i*w;
num_ol = sym(k*(var^2-4*var+13));
den_ol = expand((var+2)*(var+4)*(var));

num_rat = simplify(expand(num_ol*conj(den_ol)));
den_rat = simplify(expand(den_ol*conj(den_ol)));
g_rat(w) = simplify(expand(num_rat/den_rat))
real_g_rat = real(g_rat(w))
imag_g_rat = imag(g_rat(w))
crsovr_w = solve(real_g_rat,0)
crsovr = g_rat(crsovr_w)
%{
n = inf
limit(real_g_rat,w,n)
limit(imag_g_rat,w,n)
%}

figure
nyquist(g_ol)
grid on
set(gcf,'Position',[100,-500,800,650])
% xlim([-0.2,0.1])
% ylim([-1,1])

figure
bode(g_ol)
grid on
set(gcf,'Position',[100,-500,750,600])