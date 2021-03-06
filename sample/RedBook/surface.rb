#
# (c) Copyright 1993, Silicon Graphics, Inc.
# ALL RIGHTS RESERVED 
# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies and that both the copyright notice
# and this permission notice appear in supporting documentation, and that 
# the name of Silicon Graphics, Inc. not be used in advertising
# or publicity pertaining to distribution of the software without specific,
# written prior permission. 
#
# THE MATERIAL EMBODIED ON THIS SOFTWARE IS PROVIDED TO YOU "AS-IS"
# AND WITHOUT WARRANTY OF ANY KIND, EXPRESS, IMPLIED OR OTHERWISE,
# INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY OR
# FITNESS FOR A PARTICULAR PURPOSE.  IN NO EVENT SHALL SILICON
# GRAPHICS, INC.  BE LIABLE TO YOU OR ANYONE ELSE FOR ANY DIRECT,
# SPECIAL, INCIDENTAL, INDIRECT OR CONSEQUENTIAL DAMAGES OF ANY
# KIND, OR ANY DAMAGES WHATSOEVER, INCLUDING WITHOUT LIMITATION,
# LOSS OF PROFIT, LOSS OF USE, SAVINGS OR REVENUE, OR THE CLAIMS OF
# THIRD PARTIES, WHETHER OR NOT SILICON GRAPHICS, INC.  HAS BEEN
# ADVISED OF THE POSSIBILITY OF SUCH LOSS, HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, ARISING OUT OF OR IN CONNECTION WITH THE
# POSSESSION, USE OR PERFORMANCE OF THIS SOFTWARE.
# 
# US Government Users Restricted Rights 
# Use, duplication, or disclosure by the Government is subject to
# restrictions set forth in FAR 52.227.19(c)(2) or subparagraph
# (c)(1)(ii) of the Rights in Technical Data and Computer Software
# clause at DFARS 252.227-7013 and/or in similar or successor
# clauses in the FAR or the DOD or NASA FAR Supplement.
# Unpublished-- rights reserved under the copyright laws of the
# United States.  Contractor/manufacturer is Silicon Graphics,
# Inc., 2011 N.  Shoreline Blvd., Mountain View, CA 94039-7311.
#
# OpenGL(TM) is a trademark of Silicon Graphics, Inc.
#
#
# surface.c
# This program draws a NURBS surface in the shape of a 
# symmetrical hill.
#
require '../util/setup_dll'

include OpenGL
include GLU
include GLFW

$ctlpoints = Array.new(4).collect { Array.new(4).collect { Array.new(3, nil) } } # 4*4*3 array
$showPoints = 0

$theNurb = nil

# Initializes the control points of the surface to a small hill.
# The control points range from -3 to +3 in x, y, and z
def init_surface
	for u in 0..3
		for v in 0..3
			$ctlpoints[u][v][0] = 2.0*(u - 1.5)
			$ctlpoints[u][v][1] = 2.0*(v - 1.5)
			
			if ( (u == 1 || u == 2) && (v == 1 || v == 2))
				$ctlpoints[u][v][2] = 3
			else
				$ctlpoints[u][v][2] = -3
			end
		end
	end
end			
			
# Initialize material property and depth buffer.
def myinit
	mat_diffuse = [ 0.7, 0.7, 0.7, 1.0 ]
	mat_specular = [ 1.0, 1.0, 1.0, 1.0 ]
	mat_shininess = 100.0
	
	glClearColor(0.0, 0.0, 0.0, 1.0)
	glMaterialfv(GL_FRONT, GL_DIFFUSE, mat_diffuse.pack('F*'))
	glMaterialfv(GL_FRONT, GL_SPECULAR, mat_specular.pack('F*'))
	glMaterialf(GL_FRONT, GL_SHININESS, mat_shininess)
	
	glEnable(GL_LIGHTING)
	glEnable(GL_LIGHT0)
	glDepthFunc(GL_LESS)
	glEnable(GL_DEPTH_TEST)
	glEnable(GL_AUTO_NORMAL)
	glEnable(GL_NORMALIZE)
	
	init_surface()
	
	$theNurb = gluNewNurbsRenderer()
	gluNurbsProperty($theNurb, GLU_SAMPLING_TOLERANCE, 25.0)
	gluNurbsProperty($theNurb, GLU_DISPLAY_MODE, GLU_FILL)
end

display = Proc.new do
	knots = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0]
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	
	glPushMatrix()
	glRotatef(330.0, 1.0,0.0,0.0)
	glScalef(0.5, 0.5, 0.5)
	
	gluBeginSurface($theNurb)
	gluNurbsSurface($theNurb, 
		8, knots.pack('F*'),
		8, knots.pack('F*'),
		4 * 3,
		3,
		$ctlpoints.flatten.pack('F*'), 
		4, 4,
		GL_MAP2_VERTEX_3)
	gluEndSurface($theNurb)
	
	if($showPoints==1)
		glPointSize(5.0)
		glDisable(GL_LIGHTING)
		glColor3f(1.0, 1.0, 0.0)
		glBegin(GL_POINTS)
		for i in 0..3
			for j in 0..3
				glVertex3f($ctlpoints[i][j][0], $ctlpoints[i][j][1], $ctlpoints[i][j][2])
			end
		end
		glEnd()
		glEnable(GL_LIGHTING)
	end
		
	glPopMatrix()
end

size_callback = GLFW::create_callback( :GLFWwindowsizefun ) do|window_handle, w, h|
	glViewport(0, 0, w, h)
	glMatrixMode(GL_PROJECTION)
	glLoadIdentity()
	gluPerspective(45.0, w/h, 3.0, 8.0)
	
	glMatrixMode(GL_MODELVIEW)
	glLoadIdentity()
	glTranslatef(0.0, 0.0, -5.0)
end

key_callback = GLFW::create_callback(:GLFWkeyfun) do |window_handle, key, scancode, action, mods|
  case key
  when GLFW_KEY_S
    if action == GLFW_PRESS
      $showPoints = ($showPoints == 0 ? 1 : 0)
    end
  when GLFW_KEY_ESCAPE
    glfwSetWindowShouldClose(window_handle, 1)
  end
end

if __FILE__ == $0
  glfwInit()
  window = glfwCreateWindow( 500, 500, $0, nil, nil )
  glfwSetWindowPos( window, 100, 100 )
  glfwMakeContextCurrent( window )
  glfwSetKeyCallback( window, key_callback )
  glfwSetWindowSizeCallback( window, size_callback )

  myinit()

  width_ptr = ' ' * 4
  height_ptr = ' ' * 4
  glfwGetFramebufferSize(window, width_ptr, height_ptr)
  width = width_ptr.unpack('L')[0]
  height = height_ptr.unpack('L')[0]
  size_callback.call( window, width, height )

  while glfwWindowShouldClose( window ) == 0
    display.call
    glfwSwapBuffers( window )
    glfwPollEvents()
  end

  glfwDestroyWindow( window )
  glfwTerminate()
end
