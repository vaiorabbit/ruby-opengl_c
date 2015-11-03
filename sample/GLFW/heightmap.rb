=begin
Ref.: glfw-3.1.2/examples/heightmap.c
Original Copyright Notice:
//========================================================================
// Heightmap example program using OpenGL 3 core profile
// Copyright (c) 2010 Olivier Delannoy
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would
//    be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source
//    distribution.
//
//========================================================================
=end
require '../util/setup_dll'
require '../util/rmath3d_plain'

include RMath3D
include OpenGL
include GLFW

# Map height updates
MAX_CIRCLE_SIZE = 5.0
MAX_DISPLACEMENT = 1.0
DISPLACEMENT_SIGN_LIMIT = 0.3
MAX_ITER = 200
NUM_ITER_AT_A_TIME = 1

# Map general information
MAP_SIZE = 10.0
MAP_NUM_VERTICES = 80
MAP_NUM_TOTAL_VERTICES = MAP_NUM_VERTICES*MAP_NUM_VERTICES
MAP_NUM_LINES = (3* (MAP_NUM_VERTICES - 1) * (MAP_NUM_VERTICES - 1) + 2 * (MAP_NUM_VERTICES - 1))


=begin
/**********************************************************************
 * Default shader programs
 *********************************************************************/
=end

vertex_shader_text = <<VSH
#version 150
uniform mat4 project;
uniform mat4 modelview;
in float x;
in float y;
in float z;

void main()
{
   gl_Position = project * modelview * vec4(x, y, z, 1.0);
}
VSH

fragment_shader_text = <<FSH
#version 150
out vec4 color;
void main()
{
    color = vec4(0.2, 1.0, 0.2, 1.0);
}
FSH

=begin
/**********************************************************************
 * Values for shader uniforms
 *********************************************************************/
=end

# Frustum configuration
$view_angle = 45.0
$aspect_ratio = 4.0/3.0
$z_near = 1.0
$z_far = 100.0

# Projection matrix
$projection_matrix = [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
]

# Model view matrix
$modelview_matrix = [
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
]

=begin
/**********************************************************************
 * Heightmap vertex and index data
 *********************************************************************/
=end

$map_vertices = Array.new(3) { Array.new(MAP_NUM_TOTAL_VERTICES) { 0.0 } }
$map_line_indices = Array.new(2*MAP_NUM_LINES) { 0 }

=begin
/* Store uniform location for the shaders
 * Those values are setup as part of the process of creating
 * the shader program. They should not be used before creating
 * the program.
 */
=end
$mesh = 0
$mesh_vbo = nil # Array.new(4) { 0 }

=begin
/**********************************************************************
 * OpenGL helper functions
 *********************************************************************/
=end

# Creates a shader object of the specified type using the specified text
def make_shader(type, text) # (GLenum type, const char* text)

  shader = 0
  shader_ok = 0
  shader_ok_buf = ' ' * 4
  log_length = 0
  log_length_buf = ' ' * 4
  info_log = ' ' * 8192

  shader = glCreateShader(type)
  if (shader != 0)

    glShaderSource(shader, 1, [text].pack('p'), nil)
    glCompileShader(shader)
    glGetShaderiv(shader, GL_COMPILE_STATUS, shader_ok_buf)
    shader_ok = shader_ok_buf.unpack('L')[0]
    if shader_ok != GL_TRUE

      $stderr.printf( "ERROR: Failed to compile %s shader\n", (type == GL_FRAGMENT_SHADER) ? "fragment" : "vertex" )
      glGetShaderInfoLog(shader, 8192, log_length_buf, info_log)
      log_length = log_length_buf.unpack('L')[0]
      $stderr.printf( "ERROR: \n%s\n\n", info_log)
      glDeleteShader(shader)
      shader = 0
    end
  end

  return shader
end

# Creates a program object using the specified vertex and fragment text
def make_shader_program(vs_text, fs_text) # (const char* vs_text, const char* fs_text)

  program = 0
  program_ok = 0
  program_ok_buf = ' ' * 4
  vertex_shader = 0
  fragment_shader = 0
  log_length = 0
  log_length_buf = ' ' * 4
  info_log = ' ' * 8192

  vertex_shader = make_shader(GL_VERTEX_SHADER, vs_text)
  if vertex_shader != 0
    fragment_shader = make_shader(GL_FRAGMENT_SHADER, fs_text)
    if fragment_shader != 0

      # make the program that connect the two shader and link it
      program = glCreateProgram()
      if program != 0

        # attach both shader and link
        glAttachShader(program, vertex_shader)
        glAttachShader(program, fragment_shader)
        glLinkProgram(program)
        glGetProgramiv(program, GL_LINK_STATUS, program_ok_buf)
        program_ok = program_ok_buf.unpack('L')[0]

        if program_ok != GL_TRUE
          $stderr.printf( "ERROR, failed to link shader program\n")
          glGetProgramInfoLog(program, 8192, log_length_buf, info_log)
          log_length = log_length_buf.unpack('L')[0]
          $stderr.printf( "ERROR: \n%s\n\n", info_log)
          glDeleteProgram(program)
          glDeleteShader(fragment_shader)
          glDeleteShader(vertex_shader)
          program = 0
        end
      end

    else

      $stderr.printf( "ERROR: Unable to load fragment shader\n")
      glDeleteShader(vertex_shader)
    end
  else

    $stderr.printf( "ERROR: Unable to load vertex shader\n")
  end

  return program
end

=begin
/**********************************************************************
 * Geometry creation functions
 *********************************************************************/
=end

# Generate vertices and indices for the heightmap
def init_map()

  i = 0
  j = 0
  k = 0
  step = MAP_SIZE / (MAP_NUM_VERTICES - 1)
  x = 0.0
  z = 0.0

  # Create a flat grid
  k = 0
  MAP_NUM_VERTICES.times do |i|
    MAP_NUM_VERTICES.times do |j|
      $map_vertices[0][k] = x
      $map_vertices[1][k] = 0.0
      $map_vertices[2][k] = z
      z += step
      k += 1
    end
    x += step
    z = 0.0
  end
=begin
   /* create indices */
   /* line fan based on i
   * i+1
   * |  / i + n + 1
   * | /
   * |/
   * i --- i + n
   */
=end
  # close the top of the square
  k = 0
  (0...(MAP_NUM_VERTICES-1)).each do |i|
    $map_line_indices[k] = (i + 1) * MAP_NUM_VERTICES - 1
    k += 1
    $map_line_indices[k] = (i + 2) * MAP_NUM_VERTICES - 1
    k += 1
  end
  # close the right of the square
  (0...(MAP_NUM_VERTICES-1)).each do |i|
    $map_line_indices[k] = (MAP_NUM_VERTICES - 1) * MAP_NUM_VERTICES + i
    k += 1
    $map_line_indices[k] = (MAP_NUM_VERTICES - 1) * MAP_NUM_VERTICES + i + 1
    k += 1
  end

  (0...(MAP_NUM_VERTICES-1)).each do |i|
    (0...(MAP_NUM_VERTICES-1)).each do |j|
      ref = i * (MAP_NUM_VERTICES) + j
      $map_line_indices[k] = ref
      k += 1
      $map_line_indices[k] = ref + 1
      k += 1

      $map_line_indices[k] = ref
      k += 1
      $map_line_indices[k] = ref + MAP_NUM_VERTICES
      k += 1

      $map_line_indices[k] = ref
      k += 1
      $map_line_indices[k] = ref + MAP_NUM_VERTICES + 1
      k += 1
    end
  end
end

def generate_heightmap__circle()
  sign = 0.0
  # random value for element in between [0-1.0]
  center_x = (MAP_SIZE * rand())
  center_y = (MAP_SIZE * rand())
  size = (MAX_CIRCLE_SIZE * rand())
  sign = rand()
  sign = (sign < DISPLACEMENT_SIGN_LIMIT) ? -1.0 : 1.0
  displacement = (sign * (MAX_DISPLACEMENT * rand()))
  return center_x, center_y, size, displacement
end

=begin
/* Run the specified number of iterations of the generation process for the
 * heightmap
 */
=end
def update_map(num_iter)
  while num_iter > 0
    # center of the circle
    center_x = 0.0
    center_z = 0.0
    circle_size = 0.0
    disp = 0.0

    center_x, center_z, circle_size, disp = generate_heightmap__circle()
    disp = disp / 2.0
    MAP_NUM_TOTAL_VERTICES.times do |ii|
      dx = center_x - $map_vertices[0][ii]
      dz = center_z - $map_vertices[2][ii]
      pd = (2.0 * Math.sqrt((dx * dx) + (dz * dz))) / circle_size
      if pd.abs <= 1.0
        # tx,tz is within the circle
        new_height = disp + (Math.cos(pd*3.14)*disp)
        $map_vertices[1][ii] += new_height
      end
    end
    num_iter -= 1
  end
end

=begin
/**********************************************************************
 * OpenGL helper functions
 *********************************************************************/
=end

=begin
/* Create VBO, IBO and VAO objects for the heightmap geometry and bind them to
 * the specified program object
 */
=end
def make_mesh(program)
  attrloc = 0

  mesh_buf = ' ' * 4
  glGenVertexArrays(1, mesh_buf)
  $mesh = mesh_buf.unpack('L')[0]
  mesh_vbo_buf = ' ' * 4 * 4
  glGenBuffers(4, mesh_vbo_buf)
  $mesh_vbo = mesh_vbo_buf.unpack('L4')

  glBindVertexArray($mesh)
  # Prepare the data for drawing through a buffer inidices
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, $mesh_vbo[3])
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, Fiddle::SIZEOF_INT * MAP_NUM_LINES * 2, $map_line_indices.pack('L*'), GL_STATIC_DRAW)

  # Prepare the attributes for rendering
  attrloc = glGetAttribLocation(program, "x")
  glBindBuffer(GL_ARRAY_BUFFER, $mesh_vbo[0])
  glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * MAP_NUM_TOTAL_VERTICES, $map_vertices[0].pack('F*'), GL_STATIC_DRAW)
  glEnableVertexAttribArray(attrloc)
  glVertexAttribPointer(attrloc, 1, GL_FLOAT, GL_FALSE, 0, nil)

  attrloc = glGetAttribLocation(program, "z")
  glBindBuffer(GL_ARRAY_BUFFER, $mesh_vbo[2])
  glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * MAP_NUM_TOTAL_VERTICES, $map_vertices[2].pack('F*'), GL_STATIC_DRAW)
  glEnableVertexAttribArray(attrloc)
  glVertexAttribPointer(attrloc, 1, GL_FLOAT, GL_FALSE, 0, nil)

  attrloc = glGetAttribLocation(program, "y")
  glBindBuffer(GL_ARRAY_BUFFER, $mesh_vbo[1])
  glBufferData(GL_ARRAY_BUFFER, Fiddle::SIZEOF_FLOAT * MAP_NUM_TOTAL_VERTICES, $map_vertices[1].pack('F*'), GL_DYNAMIC_DRAW)
  glEnableVertexAttribArray(attrloc)
  glVertexAttribPointer(attrloc, 1, GL_FLOAT, GL_FALSE, 0, nil)
end

# Update VBO vertices from source data
def update_mesh()
  glBufferSubData(GL_ARRAY_BUFFER, 0, Fiddle::SIZEOF_FLOAT * MAP_NUM_TOTAL_VERTICES, $map_vertices[1].pack('F*'))
  # pData = glMapBuffer(GL_ARRAY_BUFFER, GL_WRITE_ONLY)
  # # p pData.to_s(4)
  # pData[0, 64] = "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"
  # glUnmapBuffer(GL_ARRAY_BUFFER)

end

=begin
/**********************************************************************
 * GLFW callback functions
 *********************************************************************/
=end

# Press ESC to exit.
key_callback = GLFW::create_callback(:GLFWkeyfun) do |window_handle, key, scancode, action, mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS
    glfwSetWindowShouldClose(window_handle, 1)
  end
end

error_callback = GLFW::create_callback(:GLFWerrorfun) do |error, description|
  $stderr.printf( "Error: %s\n", description)
end

if __FILE__ == $0
  glfwSetErrorCallback(error_callback)

  glfwInit()

  glfwWindowHint(GLFW_RESIZABLE, GL_FALSE)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2)
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)

  window = glfwCreateWindow(800, 600, "GLFW OpenGL3 Heightmap demo", nil, nil)
  if window == nil
    glfwTerminate()
    exit
  end

  # Register events callback
  glfwSetKeyCallback(window, key_callback)

  glfwMakeContextCurrent( window )

  # Prepare opengl resources for rendering
  shader_program = make_shader_program(vertex_shader_text, fragment_shader_text)
  if shader_program == 0
    glfwTerminate()
    exit
  end

  glUseProgram(shader_program)
  uloc_project   = glGetUniformLocation(shader_program, "project")
  uloc_modelview = glGetUniformLocation(shader_program, "modelview")

  # Compute the projection matrix 
  f = 1.0 / Math.tan($view_angle / 2.0)
  $projection_matrix[0]  = f / $aspect_ratio
  $projection_matrix[5]  = f
  $projection_matrix[10] = ($z_far + $z_near)/ ($z_near - $z_far)
  $projection_matrix[11] = -1.0
  $projection_matrix[14] = 2.0 * ($z_far * $z_near) / ($z_near - $z_far)
  glUniformMatrix4fv(uloc_project, 1, GL_FALSE, $projection_matrix.pack('F16'));

  # Set the camera position
  $modelview_matrix[12]  = -5.0
  $modelview_matrix[13]  = -5.0
  $modelview_matrix[14]  = -20.0
  glUniformMatrix4fv(uloc_modelview, 1, GL_FALSE, $modelview_matrix.pack('F16'))

  # Create mesh data
  init_map()
  make_mesh(shader_program)

=begin
  /* Create vao + vbo to store the mesh */
  /* Create the vbo to store all the information for the grid and the height */
=end

  glViewport(0, 0, 800, 600)
  glClearColor(0.0, 0.0, 0.0, 0.0)

  # main loop
  frame = 0
  iter = 0
  last_update_time = glfwGetTime()

  while glfwWindowShouldClose(window) == 0
    frame += 1
    # render the next frame
    glClear(GL_COLOR_BUFFER_BIT)
    glDrawElements(GL_LINES, 2 * MAP_NUM_LINES, GL_UNSIGNED_INT, 0)

    # display and process events through callbacks
    glfwSwapBuffers(window)
    glfwPollEvents()
    # Check the frame rate and update the heightmap if needed
    dt = glfwGetTime()
    if (dt - last_update_time) > 0.2

      # generate the next iteration of the heightmap
      if iter < MAX_ITER
        update_map(NUM_ITER_AT_A_TIME)
        update_mesh()
        iter += NUM_ITER_AT_A_TIME
      end
      last_update_time = dt
      frame = 0
    end
  end

  glfwDestroyWindow( window )
  glfwTerminate()
end
