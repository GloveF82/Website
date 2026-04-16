clear; clc; close all

syms s k

zeta = 1/(2*10^(2/20));
k_b = 10^(12/20);

num_ol = sym(k_b*s*25);
den_ol = expand((s+1)*(s^2+5*2*zeta*s+25));
g_ol = tf(sym2poly(num_ol),sym2poly(den_ol))


nyquist(g_ol)
grid on
set(gcf,'Position',[100,-500,750,600])

figure
rlocus(g_ol)
grid on
set(gcf,'Position',[100,-500,750,600])