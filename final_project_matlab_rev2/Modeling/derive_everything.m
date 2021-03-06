function derive_everything() 
name = 'jumping_leg';

% Define variables for time, generalized coordinates + derivatives, controls, and parameters 
syms t  X Y th1 th2 dx dy dth1 dth2 ddx ddy ddth1 ddth2 real
syms m1 m2 m3 I1 I2 I3 c1 c2 g real % set I2 to zero for now though, motor as a point mass
syms l1 l2 real 
syms tau F_ax F_ay F_bx F_by F_cx F_cy real

% Group them
q   = [X ; Y ; th1  ; th2 ];      % generalized coordinates
dq  = [dx ; dy ; dth1 ; dth2];    % first time derivatives
ddq = [ddx ; ddy ; ddth1;ddth2];  % second time derivatives
u   = [tau];     % controls
Fc   = [F_ax ; F_ay; F_bx; F_by; F_cx; F_cy];

p   = [m1 m2 m3 I1 I2 I3 c1 c2 l1 l2 g]';        % parameters


%%% Calculate important vectors and their time derivatives.

% Define fundamental unit vectors.  The first element should be the
% horizontal (+x cartesian) component, the second should be the vertical (+y
% cartesian) component, and the third should be right-handed orthogonal.
ihat = [1; 0; 0];
jhat = [0; 1; 0];
khat = cross(ihat,jhat);

% Define other unit vectors for use in defining other vectors.
er1hat =  cos(th1)*ihat + sin(th1) * jhat;
er2hat = cos(th1+th2)*ihat + sin(th1+th2) * jhat;

% A handy anonymous function for taking first and second time derivatives
% of vectors using the chain rule.  See Lecture 6 for more information. 
ddt = @(r) jacobian(r,[q;dq])*[dq;ddq]; 

% Define vectors to key points.
rA = X*ihat + Y*jhat; %vector to moving origin of flip bot
rcm1 = rA + c1*er1hat; %center of mass on first bar
rB = rA + l1*er1hat; %vector to middle pivot joint on robot
rcm3 = rB + c2*er2hat; %vector to center of mass on top bar
rC = rB + l2*er2hat; %vector to tip of top bar
keypoints = [rA rB rC]; %bottom point, middle pivot, top point

% Take time derivatives of vectors as required for kinetic energy terms.
drcm1 = ddt(rcm1); %mass source 1, bottom bar, 
drcm2 = ddt(rB); %mass source 2, motor, 
drcm3 = ddt(rcm3);   %mass source 3 top bar

%%% Calculate Kinetic Energy, Potential Energy, and Generalized Forces

% F2Q calculates the contribution of a force to all generalized forces
% for forces, F is the force vector and r is the position vector of the 
% point of force application
F2Q = @(F,r) simplify(jacobian(r,q)'*(F)); 

% M2Q calculates the contribution of a moment to all generalized forces
% M is the moment vector and w is the angular velocity vector of the
% body on which the moment acts
M2Q = @(M,w) simplify(jacobian(w,dq)'*(M)); 

% Define kinetic energies. See Lecture 6 formula for kinetic energy
% of a rigid body.
T1 = (1/2)*m1*dot(drcm1, drcm1) + (1/2)* I1 * dth1^2;
T2 = (1/2)*m2*dot(drcm2, drcm2) + (1/2)* I2 * dth1^2;
T3 = (1/2)*m3*dot(drcm3, drcm3) +  (1/2)* I3 * (dth1+dth2)^2;

% Define potential energies. See Lecture 6 formulas for gravitational 
% potential energy of rigid bodies and elastic potential energies of
% energy storage elements.
V1 = m1*g*dot(rcm1, jhat);
V2 = m2*g*dot(rB, jhat);
V3 = m3*g*dot(rcm3, jhat);

% Define contributions to generalized forces.  See Lecture 6 formulas for
% contributions to generalized forces.
QF = F2Q(F_ax*ihat + F_ay*jhat,rA) + F2Q(F_bx*ihat+F_by*jhat,rB)+F2Q(F_cx*ihat+F_cy*jhat,rC); 
Qtau = M2Q(-tau*khat, -((dth2)*khat)); %??

% Sum kinetic energy terms, potential energy terms, and generalized force
% contributions.
T = T1 + T2 + T3;
V = V1 + V2 + V3;
Q = QF + Qtau;

% Calculate rcm, the location of the center of mass
rcm = (m1*rcm1 + m2*rB + m3+rcm3)/(m1+m2+m3);

% Assemble C, the set of constraints
C = Y;  % When y = 0, the constraint is satisfied because foot is on the ground
dC= ddt(C);

% other point constraints
pointC = rC;
d_pointC = ddt(rC);

pointB = rB;
d_pointB = ddt(rB);

pointA = rA;%Y;
d_pointA = ddt(rA);%ddt(C);


%% All the work is done!  Just turn the crank...
%%% Derive Energy Function and Equations of Motion
E = T+V;                                         % total system energy
L = T-V;                                         % the Lagrangian
eom = ddt(jacobian(L,dq)') - jacobian(L,q)' - Q;  % form the dynamics equations

size(eom)

%%% Rearrange Equations of Motion. 
A = jacobian(eom,ddq);
b = A*ddq - eom;


%%% Write functions to evaluate dynamics, etc...
z = sym(zeros(length([q;dq]),1)); % initialize the state vector
z(1:4,1) = q;  
z(5:8,1) = dq;

% Write functions to a separate folder because we don't usually have to see them
directory = '../AutoDerived/';
% Write a function to evaluate the energy of the system given the current state and parameters
matlabFunction(E,'file',[directory 'energy_' name],'vars',{z p});
% Write a function to evaluate the A matrix of the system given the current state and parameters
matlabFunction(A,'file',[directory 'A_' name],'vars',{z p});
% Write a function to evaluate the b vector of the system given the current state, current control, and parameters
matlabFunction(b,'file',[directory 'b_' name],'vars',{z u Fc p});

matlabFunction(keypoints,'file',[directory 'keypoints_' name],'vars',{z p});

matlabFunction(pointA,'file',[directory 'pointA_' name],'vars',{z p});
matlabFunction(d_pointA,'file',[directory 'd_pointA_' name],'vars',{z p});

matlabFunction(pointB,'file',[directory 'pointB_' name],'vars',{z p});
matlabFunction(d_pointB,'file',[directory 'd_pointB_' name],'vars',{z p});

matlabFunction(pointC,'file',[directory 'pointC_' name],'vars',{z p});
matlabFunction(d_pointC,'file',[directory 'd_pointC_' name],'vars',{z p});

% Write a function to evaluate the X and Y coordinates and speeds of the center of mass given the current state and parameters
drcm = ddt(rcm);             % Calculate center of mass velocity vector
COM = [rcm(1:2); drcm(1:2)]; % Concatenate x and y coordinates and speeds of center of mass in array
matlabFunction(COM,'file',[directory 'COM_' name],'vars',{z p});
