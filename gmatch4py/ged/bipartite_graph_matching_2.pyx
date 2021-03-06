# coding = utf-8
import numpy as np
cimport numpy as np
from ..base cimport Base

cdef class BP_2(Base):


    cdef int node_del
    cdef int node_ins
    cdef int edge_del
    cdef int edge_ins

    def __init__(self, int node_del=1, int node_ins=1, int edge_del=1, int edge_ins=1):
        """
        BP_2 Constructor

        Parameters
        ----------
        node_del :int
            Node deletion cost
        node_ins : int
            Node insertion cost
        edge_del : int
            Edge Deletion cost
        edge_ins : int
            Edge Insertion cost
        """
        Base.__init__(self,1,False)
        self.node_del = node_del
        self.node_ins = node_ins
        self.edge_del = edge_del
        self.edge_ins = edge_ins

    cpdef np.ndarray compare(self,list listgs, list selected):
        cdef int n = len(listgs)
        cdef np.ndarray comparison_matrix = np.zeros((n, n)).astype(float)
        cdef int i,j
        for i in range(n):
            for j in range(i, n):
                g1,g2=listgs[i],listgs[j]
                f=self.isAccepted(g1,i,selected)
                if f:
                    comparison_matrix[i, j] = self.bp2(g1, g2)
                else:
                    comparison_matrix[i, j] = np.inf
                comparison_matrix[j, i] = comparison_matrix[i, j]

        return comparison_matrix


    cdef double bp2(self, g1, g2):
        """
        Compute the BP2 similarity value between two `networkx.Graph`
        
        Parameters
        ----------
        g1 : networkx.Graph
            First Graph
        g2 : networkx.Graph
            Second Graph

        Returns
        -------
        float 
            similarity value
        """
        return np.min([self.distance_bp2(self.psi(g1,g2)),self.distance_bp2(self.psi(g2,g1))])

    cdef double distance_bp2(self,e):
        """
        Return the distance based on the edit path found.
        Parameters
        ----------
        e : list
            Contains the edit path costs

        Returns
        -------
        double
            Return sum of the costs from the edit path
        """
        return np.sum(e)

    cdef list psi(self,g1,g2):
        """
        Return the optimal edit path :math:`\psi` based on BP2 algorithm.
        
        
        Parameters
        ----------
        g1 : networkx.Graph
            First Graph
        g2 : networkx.Graph
            Second Graph

        Returns
        -------
        list
            list containing costs from the optimal edit path
        """
        cdef list psi_=[]
        cdef list nodes1 = list(g1.nodes)
        cdef list nodes2 = list(g2.nodes)
        for u in nodes1:
            v=None
            for w in nodes2:
                if 2*self.fuv(g1,g2,u,w) < self.fuv(g1,g2,u,None) + self.fuv(g1,g2,None,w)\
                     and self.fuv(g1,g2,u,w) < self.fuv(g1,g2,u,v):
                    v=w
                psi_.append(self.fuv(g1,g2,u,v))
            if u:
                nodes1= list(set(nodes1).difference(set([u])))
            if v:
                nodes2= list(set(nodes2).difference(set([v])))
        for v in nodes2:
            psi_.append(self.fuv(g1,g2,None,v))
        return  psi_


    cdef float sum_fuv(self, g1, g2):
        """
        Compute Nearest Neighbour Distance between G1 and G2
        :param g1: First Graph
        :param g2: Second Graph
        :return:
        """
        cdef np.ndarray min_sum = np.zeros(len(g1))
        nodes1 = list(g1.nodes)
        nodes2 = list(g2.nodes)
        nodes2.extend([None])
        cdef np.ndarray min_i
        for i in range(len(nodes1)):
            min_i = np.zeros(len(nodes2))
            for j in range(len(nodes2)):
                min_i[j] = self.fuv(g1, g2, nodes1[i], nodes2[j])
            min_sum[i] = np.min(min_i)
        return np.sum(min_sum)

    cdef float fuv(self, g1, g2, n1, n2):
        """
        Compute the Node Distance function
        :param g1: first graph
        :param g2: second graph
        :param n1: node of the first graph
        :param n2: node of the second graph
        :return:
        """
        if n2 == None:  # Del
            return self.node_del + ((self.edge_del / 2.) * g1.degree(n1))
        if n1 == None:  # Insert
            return self.node_ins + ((self.edge_ins / 2.) * g2.degree(n2))
        else:
            if n1 == n2:
                return 0
            return (self.node_del + self.node_ins + self.hed_edge(g1, g2, n1, n2)) / 2

    cdef float hed_edge(self, g1, g2, n1, n2):
        """
        Compute HEDistance between edges of n1 and n2, respectively in g1 and g2
        :param g1: first graph
        :param g2: second graph
        :param n1: node of the first graph
        :param n2: node of the second graph
        :return:
        """
        return self.sum_gpq(g1, n1, g2, n2) + self.sum_gpq(g1, n1, g2, n2)


    cdef float sum_gpq(self, g1, n1, g2, n2):
        """
        Compute Nearest Neighbour Distance between edges around n1 in G1  and edges around n2 in G2
        :param g1: first graph
        :param n1: node in the first graph
        :param g2: second graph
        :param n2: node in the second graph
        :return:
        """

        #if isinstance(g1, nx.MultiDiGraph):
        cdef list edges1 = list(g1.edges(n1)) if n1 else []
        cdef list edges2 =  list(g2.edges(n2)) if n2 else []

        cdef np.ndarray min_sum = np.zeros(len(edges1))
        edges2.extend([None])
        cdef np.ndarray min_i
        for i in range(len(edges1)):
            min_i = np.zeros(len(edges2))
            for j in range(len(edges2)):
                min_i[j] = self.gpq(edges1[i], edges2[j])
            min_sum[i] = np.min(min_i)
        return np.sum(min_sum)

    cdef float gpq(self, tuple e1, tuple e2):
        """
        Compute the edge distance function
        :param e1: edge1
        :param e2: edge2
        :return:
        """
        if e2 == None:  # Del
            return self.edge_del
        if e1 == None:  # Insert
            return self.edge_ins
        else:
            if e1 == e2:
                return 0
            return (self.edge_del + self.edge_ins) / 2.
