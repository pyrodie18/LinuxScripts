import csv
import sys

def parse(cidr):
  #Turns the network/CIDR into a bit stream equal to the networka address
  bitmask = []
  net, bits = cidr.split("/")
  bits = int(bits)
  net = map(int, net.split("."))
  net = map(lambda s: "{0:08b}".format(s), net)
  net = list(reduce(lambda a,b: a+b, net))
  net = map(int, net)[:bits]
  return net

def print_to_cidr(bitmask):
  #Converts the resulting bit stream back into network/CIDR
  if not bitmask:
    return
  bits = len(bitmask)
  oct_bit = 0
  oct_i = 0
  out = [0, 0, 0, 0]
  for i in bitmask:
    out[oct_i] *= 2
    out[oct_i] += i
    oct_bit += 1
    if oct_bit == 8:
      oct_bit = 0
      oct_i += 1
  while oct_bit < 8:
    out[oct_i] *= 2
    oct_bit += 1
  out = ".".join(map(str, out))
  print out + "/" + str(bits) + ",T"
  return

class IpBinTree:
  def __init__ (self, bm, leaf):
    self.net = bm
    self.leaf = leaf
    self.left = None
    self.right = None

  def insert (self, level, bm):
    if len(bm) > level:
      if bm[level]:
        if not self.right:
          self.right = IpBinTree(bm[0:level+1], False)
        self.right = self.right.insert(level+1, bm)
      else:
        if not self.left:
          self.left = IpBinTree(bm[0:level+1], False)
        self.left = self.left.insert(level+1, bm)
      if self.left and self.right and self.left.leaf and self.right.leaf:
        self.leaf = True
      return self
    elif len(bm) == level:
      self.leaf = True
      return self

  def walk (self):
    if self.leaf:
      return print_to_cidr(self.net)
    else:
      if self.left:
         self.left.walk()
      if self.right:
         self.right.walk()

tree = IpBinTree([], False)
if len (sys.argv)!=2 :
  print "Usage:  suppernetter.py <InputFile>"
  sys.exit(1)
with open (sys.argv[1], 'rb') as csvfile:
  for row in csvfile:
    tree = tree.insert(0, parse(row.strip()))

print "IPAddr,Found"
tree.walk()
