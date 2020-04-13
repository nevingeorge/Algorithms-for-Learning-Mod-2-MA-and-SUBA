/*
 * Author: Nevin George
 * Advisor: Dana Angluin
 * Program Description: The algorithm takes as input a SUBA and converts it into an equivalent UFA. The resulting 
 * UFA is then converted into an equivalent mod-2-MA and learned using Mod2_MA.java.
 * 
 * References:
 * 1 Amos Beimel, Francesco Bergadano, Nader H. Bshouty, Eyal Kushilevitz, Stefano Varric- chio. Learning 
 *   functions represented as multiplicity automata. J. ACM, 47(3):506–530, May 2000.
 * 2 Dana Angluin. Learning regular sets from queries and counterexamples. Inf. Comput., 75(2):87–106, 1987.
 * 3 Dana Angluin, Timos Antonopoulos, Dana Fisman. Strongly Unambiguous Büchi Automata Are Polynomially 
 *   Predictable with Membership Queries. 28th International Conference on Computer Science Logic, 8:1–8:17, 2020.
 * 4 Michael Thon and Herbert Jaeger. Links Between Multiplicity Automata, Observable Operator Models and 
 *   Predictive State Representations — a Unified Learning Framework. Journal of Machine Learning Research, 
 *   16(4):103−147, 2015.
 * 5 N. Bousquet and C. Löding. Equivalence and inclusion problem for strongly unambiguous büchi automata. In 
 *   Language and Automata Theory and Applications, 4th International Conference, LATA 2010, Trier, Germany, May 
 *   24-28, 2010. Proceedings, pages 118–129, 2010. 
 *   URL: https: //doi.org/10.1007/978-3-642-13089-2_10, doi:10.1007/978-3-642-13089-2\_10.
 */

import java.io.BufferedReader;
import java.io.FileReader;
import java.util.HashMap;
import java.util.Scanner;
import java.util.StringTokenizer;

public class SUBA {
	// SUBA = (Q, Σ, ∆, F)
	
	// Q has states q_1 to q_(Q_SUBA)
	public static int Q_SUBA;
	
	// transition matrix Δ
	public static boolean[][][] transition_SUBA;
	
	// final states F
	public static boolean[] F_SUBA;
		
	// --------------------------------------
	
	// UFA = (Q',ΣU{$},∆',F')
	
	// Q' has states q_1 to q_(Q_UFA)
	public static int Q_UFA;
	
	// transition matrix Δ'
	public static boolean[][][] transition_UFA;
	
	// final states F'
	public static boolean[] F_UFA;

	public static void main(String[] args) throws Exception {
		// converts the input SUBA into an equivalent UFA
		SUBAtoUFA();
		
		// converts the UFA into an equivalent mod-2-MA
		UFAtoMod2MA();
		
		// runs Mod2_MA.java on the mod-2-MA
		Mod2_MA.run();
		
		if(!finalCheck())
			throw new Exception("Failed final check");
	}
	
	public static void SUBAtoUFA() throws Exception {
		/* The input file containing the SUBA (Q, Σ, ∆, F) must have the following format (no line 
		 * separation, characters are space separated, and lines beginning with // are ignored):
		 * <number of states (Q)>
		 * <alphabet size>
		 * <characters in the alphabet>
		 * <final states (F)>
		 * <number of transitions>
		 * The remaining lines are the transitions, with each line having the form q_i a q_j, where q_i,q_j∈Q and a∈Σ.
		 * 
		 * By default the only initial state of the SUBA (and therefore also the UFA) is q_1.
		 * Example input files can be found in the repository.
		 */
		
		// converts the input SUBA into the UFA described in Bousquet and Löding of the form (Q',ΣU{$},∆',F')

		// reads in file name + optional flag -v from stdin
		System.out.println("Input file name and optional flag -v (e.g. SUBA_input1.txt or SUBA_input1.txt -v)");
		Scanner in = new Scanner(System.in);
		String[] arrInput = in.nextLine().split(" ");
		in.close();
		Mod2_MA.verbose = false;
		if(arrInput.length == 2 && arrInput[1].equals("-v"))
			Mod2_MA.verbose = true;
		BufferedReader f = new BufferedReader(new FileReader(arrInput[0]));
		System.out.println("");

		// number of states
		// Q' = Q U (Q x Q x {0,1})
		String line = f.readLine();
		while(line.charAt(0) == '/' && line.charAt(1) == '/')
			line = f.readLine();
		
		Q_SUBA = Integer.parseInt(line);
		Q_UFA = Q_SUBA + Q_SUBA*Q_SUBA*2;
		
		// --------------------------------------------------------------------------------------
		
		// alphabet size
		line = f.readLine();
		while(line.charAt(0) == '/' && line.charAt(1) == '/')
			line = f.readLine();
		
		// add {$} to the language
		Mod2_MA.alphabetSize = Integer.parseInt(line) + 1;
		
		// alphabet ΣU{$}
		line = f.readLine();
		while(line.charAt(0) == '/' && line.charAt(1) == '/')
			line = f.readLine();
		StringTokenizer st = new StringTokenizer(line);
		
		Mod2_MA.alphabet = new Character[Mod2_MA.alphabetSize];
		for(int i=0;i<Mod2_MA.alphabetSize-1;i++) {
			String letter = st.nextToken();
			if(letter.length()!=1 || letter.charAt(0) == '$') {
				f.close();
				throw new Exception("Invalid input: invalid character in the alphabet");
			}
			Mod2_MA.alphabet[i] = letter.charAt(0);
		}
		Mod2_MA.alphabet[Mod2_MA.alphabetSize-1] = '$';
		
		if(st.hasMoreTokens()) {
			f.close();
			throw new Exception("Invalid input: alphabet size exceeds the specified size");
		}
		
		// maps each letter in alphabet to an index
		Mod2_MA.letterToIndex = new HashMap<Character, Integer>();
		for(int i=0;i<Mod2_MA.alphabetSize;i++)
			Mod2_MA.letterToIndex.put(Mod2_MA.alphabet[i], i);
		
		// --------------------------------------------------------------------------------------
		
		// final states for the SUBA
		line = f.readLine();
		while(line.charAt(0) == '/' && line.charAt(1) == '/')
			line = f.readLine();
		st = new StringTokenizer(line);
		
		F_SUBA = new boolean[Q_SUBA+1];
		while(st.hasMoreTokens()) {
			int state = Integer.parseInt(st.nextToken());
			if(1<=state && state<=Q_SUBA && !F_SUBA[state])
				F_SUBA[state] = true;
			else {
				f.close();
				throw new Exception("Invalid input: invalid or duplicate final state");
			}
		}
		// --------------------------------------------------------------------------------------
		
		/* Following the paper by Bousquet and Löding, Δ' contains (where q,p,p'∈Q)
		 * - all transitions from Δ
		 * - all transitions of the form (q,$,(q,q,0))
		 * - all transitions of the form ((q,p,i),a,(q,p',i')), where (p,a,p')∈Δ, and
		 * 	 i' = 1 if p'∈F and i if p'∉F
		 * 
		 * Transitions will be stored in a Q_UFA x alphabetSize x Q_UFA adjacency matrix.
		 * The first Q_SUBA states of Δ' will be the states of the SUBA.
		 * The remaining states will be of the form (q_j,q_k,i), where q_j,q_k∈Q and i∈{0,1}.
		 * State (q_j,q_k,i) will be found at index (2*Q_SUBA*j)+(2*k)-(Q_SUBA)+(i-1) of Δ'.
		*/
		
		// number of transitions
		line = f.readLine();
		while(line.charAt(0) == '/' && line.charAt(1) == '/')
			line = f.readLine();

		int numTransitions = Integer.parseInt(line);
		if(numTransitions<1 || numTransitions>((Mod2_MA.alphabetSize-1)*Q_SUBA*Q_SUBA)) {
			f.close();
			throw new Exception("Invalid input: invalid number of transitions");
		}
		
		// transition matrices Δ and Δ': (start state, letter, end state)
		transition_SUBA = new boolean[Q_SUBA+1][Mod2_MA.alphabetSize][Q_SUBA+1];
		transition_UFA = new boolean[Q_UFA+1][Mod2_MA.alphabetSize][Q_UFA+1];
		
		// lines of the form q_j a q_k, where q_j,q_k∈Q
		for(int i=0;i<numTransitions;i++) {
			line = f.readLine();
			while(line.charAt(0) == '/' && line.charAt(1) == '/')
				line = f.readLine();
			
			st = new StringTokenizer(line);
			int p_start = Integer.parseInt(st.nextToken());
			
			String letter = st.nextToken();
			if(letter.length()!=1) {
				f.close();
				throw new Exception("Invalid input: invalid transition");
			}
			int a = Mod2_MA.letterToIndex.get(letter.charAt(0));
			
			int p_end = Integer.parseInt(st.nextToken());
			
			if(p_start<1 || p_start>Q_SUBA || p_end<1 || p_end>Q_SUBA) {
				f.close();
				throw new Exception("Invalid input: invalid transition");
			}
			
			// Δ ⊆ Δ' 
			transition_SUBA[p_start][a][p_end] = true;
			transition_UFA[p_start][a][p_end] = true;
			
			// transitions of the form ((q,p,i),a,(q,p',i'))
			// p'∈F so i'=1
			if(F_SUBA[p_end]) {
				for(int q=1;q<=Q_SUBA;q++) {
					// ((q,p,0),a,(q,p',1))
					transition_UFA[2*Q_SUBA*q+2*p_start-Q_SUBA-1][a][2*Q_SUBA*q+2*p_end-Q_SUBA] = true;
					// ((q,p,1),a,(q,p',1))
					transition_UFA[2*Q_SUBA*q+2*p_start-Q_SUBA][a][2*Q_SUBA*q+2*p_end-Q_SUBA] = true;
				}
			}
			// p'∉F so i'=i
			else {
				for(int q=1;q<=Q_SUBA;q++) {
					// ((q,p,0),a,(q,p',0))
					transition_UFA[2*Q_SUBA*q+2*p_start-Q_SUBA-1][a][2*Q_SUBA*q+2*p_end-Q_SUBA-1] = true;
					// ((q,p,1),a,(q,p',1))
					transition_UFA[2*Q_SUBA*q+2*p_start-Q_SUBA][a][2*Q_SUBA*q+2*p_end-Q_SUBA] = true;
				}
			}
		}

		// --------------------------------------------------------------------------------------
		
		// transitions for the UFA of the form (q,$,(q,q,0)), where q∈Q
		// final states for the UFA of the form (q,q,1), where q∈Q
		F_UFA = new boolean[Q_UFA+1];
		for(int q=1;q<=Q_SUBA;q++) {
			transition_UFA[q][Mod2_MA.letterToIndex.get('$')][2*Q_SUBA*q+2*q-Q_SUBA-1] = true;
			F_UFA[2*Q_SUBA*q+2*q-Q_SUBA] = true;
		}
		
		line = f.readLine();
		while(line!=null) {
			if(line.charAt(0) != '/' && line.charAt(1) != '/') {
				f.close();
				throw new Exception("Invalid input: more transitions inputted than specified");
			}
			line = f.readLine();
		}
		f.close();
	}

	public static void UFAtoMod2MA() {
		// size of the target function equals the number of states in the UFA
		Mod2_MA.r = Q_UFA;
		
		// fy is the characteristic vector of F
		Mod2_MA.fy = new int[Mod2_MA.r];
		for(int i=1;i<=Q_UFA;i++) {
			if(F_UFA[i])
				Mod2_MA.fy[i-1] = 1;
		}
		
		// for each σ∈Σ, [μ_σ]i,j = 1 if and only if (q_i,σ,q_j)∈∆
		Mod2_MA.fu = new int[Mod2_MA.alphabetSize][Mod2_MA.r][Mod2_MA.r];
		for(int i=0;i<Mod2_MA.alphabetSize;i++) {
			for(int j=1;j<=Mod2_MA.r;j++) {
				for(int k=1;k<=Mod2_MA.r;k++) {
					if(transition_UFA[j][i][k])
						Mod2_MA.fu[i][j-1][k-1] = 1;
				}
			}
		}
		
		// general variables to initialize
		
		Mod2_MA.checkLength = 100;
		Mod2_MA.numToCheck = 20;
		
		// initial size of X and Y
		Mod2_MA.l = 1;
	}
	
	public static boolean finalCheck() {
		return true;
	}
}