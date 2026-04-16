clear; clc; close all

syms s k
k = 4.35*(s+1);
num_tf = expand(2*k*(0.08*s+1));
den_tf = expand((s+10)*(10*s^2)*(0.08*s+1) + 40*k);
t = tf(sym2poly(num_tf),sym2poly(den_tf))

num_ol = sym(40*s+40);
den_ol = expand((s+10)*(10*s^2)*(0.08*s+1));
g_ol = tf(sym2poly(num_ol),sym2poly(den_ol));

rlocus(g_ol)
set(gcf,'Position',[100,-500,750,600])
xlim([-3,1])
ylim([-5,5])
xline(-1,':')
yline([1,-1],':')
sgrid(0.4,2)