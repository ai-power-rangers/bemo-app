Here is a formal optimization problem formulation to find the minimal movement required to solve a Tangram puzzle.
The problem is to find a single global rigid transformation (rotation and translation) for the entire target puzzle shape that minimizes the sum of movements (translation distance and rotation change) for all individual pieces from their starting positions.

1. Definitions and Variables
First, let’s define the terms for the N pieces in the puzzle.
Index:
i∈{1,2,…,N} identifies each Tangram piece.
Given Inputs (Constants):
si​∈R2: The initial 2D position vector (e.g., center of mass) of piece i.
ϕi,start​∈[0,2π): The initial rotation angle of piece i.
pi′​∈R2: The target position vector of piece i within the puzzle’s own local coordinate frame.
ψi,target′​∈[0,2π): The target rotation angle of piece i within the puzzle’s local coordinate frame.
Decision Variables: These are the variables we need to find.
T∈R2: The global translation vector to apply to the entire solved puzzle.
Θ∈[0,2π): The global rotation angle to apply to the entire solved puzzle.
Derived Final State: The final position and rotation of each piece are determined by applying the global transformation (T,Θ) to the target configuration.
fi​(T,Θ)=R(Θ)pi′​+T: The final position of piece i.
ϕi,final​(Θ)=ψi,target′​+Θ: The final rotation of piece i.
R(Θ) is the 2D rotation matrix: R(Θ)=(cosΘsinΘ​−sinΘcosΘ​).
2. The Objective Function
The goal is to minimize the total cost function, J(T,Θ), which is the weighted sum of all squared translational distances and all squared angular distances for the pieces.
T,Θmin​J(T,Θ)=i=1∑N​(wt​∥fi​(T,Θ)−si​∥22​+wr​⋅dθ​(ϕi,final​(Θ),ϕi,start​)2)
Where:
wt​ and wr​ are user-defined positive weights that balance the importance of minimizing translation versus rotation. For example, if you want to prioritize less turning, you would make wr​ larger than wt​.
∥⋅∥22​ is the squared Euclidean distance (squared length of the translation vector).
dθ​(α,β) is the shortest angle between two angles α and β. This is crucial to correctly handle angle wrapping (e.g., the distance between 359∘ and 1∘ is 2∘, not 358∘). Mathematically, dθ​(α,β)=min(∣α−β∣,2π−∣α−β∣).
3. Solution Strategy
This problem can be solved efficiently by first solving for the optimal translation T in terms of the rotation Θ, and then solving for the single variable Θ.
Step 1: Decouple Translation from Rotation
For any fixed global rotation Θ, the optimal global translation T∗(Θ) can be calculated analytically. It is the translation that aligns the centroid of the starting positions with the centroid of the rotated target positions.
Calculate the centroid of the starting positions: sˉ=N1​∑i=1N​si​.
Calculate the centroid of the local target positions: pˉ​′=N1​∑i=1N​pi′​.
The optimal translation T∗ is given by:
T∗(Θ)=sˉ−R(Θ)pˉ​′
Step 2: Reduce to a 1D Optimization Problem
Substitute the expression for T∗(Θ) back into the main objective function. This eliminates T and leaves a new objective function, J(Θ), that depends only on the global rotation angle Θ.
J(Θ)=i=1∑N​(wt​∥(si​−sˉ)−R(Θ)(pi′​−pˉ​′)∥22​+wr​⋅dθ​(ψi,target′​+Θ,ϕi,start​)2)
This formula simplifies the problem to finding the angle Θ that minimizes the sum of squared distances between the centered start and centered, rotated target positions, plus the rotational cost.
Step 3: Solve for the Optimal Rotation Θ∗
The function J(Θ) is a non-convex function of a single variable over a bounded interval [0,2π). This can be solved reliably using numerical methods:
Grid Search: A straightforward approach is to evaluate J(Θ) for a range of angles (e.g., every 0.5 degrees from 0 to 360) and select the angle Θ∗ that results in the minimum cost.
Numerical Solver: Use a one-dimensional numerical optimization algorithm (like Brent’s method or a gradient-based method) to find the minimum of J(Θ). Since the function may have multiple local minima, it’s best to use several starting points.
Step 4: Determine the Final Solution
Once the optimal rotation Θ∗ is found in Step 3:
Calculate the optimal translation T∗ using the formula from Step 1:
T∗=sˉ−R(Θ∗)pˉ​′
The pair (T∗,Θ∗) is the solution. It defines the optimal placement of the final puzzle.
The specific final position and rotation for each piece i are:
Final Position: fi∗​=R(Θ∗)pi′​+T∗
Final Rotation: ϕi,final∗​=ψi,target′​+Θ∗

--

