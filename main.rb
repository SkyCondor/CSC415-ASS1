# Language: Ruby, Level: Level 4
require 'csv'
require 'pp'
def main()

  if ARGV.size != 4
    puts "error argv!"
  end

  in_course_path = ARGV[0]
  in_student_path = ARGV[1]
  out_course_path = ARGV[2]
  out_student_path = ARGV[3]

  pp in_course_path
  pp in_student_path
  pp out_course_path
  pp out_student_path
  sleep(20)

#  in_course_path = 'course_constraints.csv'
#  in_student_path = 'student_prefs.csv'
#  out_course_path = '1.csv'
#  out_student_path = '2.csv'

  courses = parse_in_course(in_course_path)
  students, courses_students = parse_in_student(in_student_path)

  course_map = {}
  course_out = {}
  course_out.default = []
  student_out = {}
  student_out.default = []

  while (course = pick_course(courses, courses_students))
    picks = pick_students(course, students, courses_students)
    course_name = course['course_name'] ++ '_0' ++ course['section'].to_s
    course_map[course_name] = course
    for s_id in picks
      pick_student = students[s_id]
      course_out[course_name] = course_out[course_name].push(pick_student)
      student_out[s_id] = student_out[s_id].push(course)
    end

  end

  for s_id in students.keys
    student = students[s_id]
    if student['get'] < student['num']
      for course_name in course_map.keys
        if student['get'] >= student['num']
          break
        end

        course = course_map[course_name]
        for student_course_name in student['courses'].keys
          if student['get'] >= student['num']
            break
          end
          if course_name.include?(student_course_name) and (course['cur_num'] < course['max_num'])
            course['cur_num'] = course['cur_num'] + 1
            student['get'] = student['get']  + 1
            course_out[course_name] = course_out[course_name].push(student)
            student_out[student['s_id']] = student_out['s_id'].push(course)
          end
        end
      end

    end
  end

  make_out(out_course_path, out_student_path, course_out, student_out, course_map, students)
end

def make_out(course_path, student_path,course_out, student_out, course_map, all_students)
  CSV.open(course_path, 'wb') do |course_file|
    for course_name in course_out.keys
      students = course_out[course_name]
      course = course_map[course_name]
      name, section = course_name.split('_')
      s_ids = []
      for student in students
        s_ids.push(student['s_id'])
      end
      s_ids_str = s_ids.join(';')
      fill_num = course['cur_num']
      open_num = course['max_num'] - fill_num
      course_file << [name, section, s_ids_str, fill_num, open_num]

    end
  end
  CSV.open(student_path, 'wb') do |student_file|
    for s_id in all_students.keys

      student = all_students[s_id]
      courses_names_str = ''
      reason = ''
      if student_out.has_key?(s_id)
        courses = student_out[s_id]
        courses_names = []
        for course in courses
         courses_names.push(course['course_name'])
        end
        courses_names_str = courses_names.join(';')
      end

      if student['get'] < student['num']
        reason = 'not enough course'
      end

      student_file << [s_id, courses_names_str, reason]


      courses = student_out[s_id]
      course_names = []
      for course in courses
        course_names.push(course['course_name'])
      end

      course_names_str = course_names.join(';')
    end
  end


end

def pick_students(course, students, courses_students)
  pick_count = 0
  min_num = course['min_num']
  course_name = course['course_name']
  picks = []
  for s_id in courses_students[course_name].keys
    if pick_count < min_num
      picks.push(s_id)
      pick_count = pick_count + 1
      course['cur_num'] = course['cur_num'] + 1
    else
      break
    end
  end

  for s_id in picks
    student = students[s_id]
    student['get'] = student['get'] +  1
    if student['num'] > 1
      student['num'] = 1
      courses_students[course_name].delete(s_id)
    else
      for student_course_name in student['courses'].keys
        courses_students[student_course_name].delete(s_id)
      end
    end
  end

  picks
end


def pick_course(courses, courses_students)
  for course_name in courses.keys
    if courses_students.has_key?(course_name) && courses[course_name]['min_num'] <= courses_students[course_name].keys.size
      course = courses[course_name]
      select_course = course.dup()
      if course['num_of_section']  == course['section']
        courses_students.delete(course_name)
      else
        course['section'] = course['section'] + 1
      end
      return select_course
    end
  end

  nil
end



def parse_in_course(path)

  data = {}
  count = 0
  CSV.foreach path do |row|
    if count != 0
    item =  {}
    course_name = row[0].to_s.lstrip.rstrip
    num_of_section = row[1].to_s.lstrip.rstrip.to_i
    min_num = row[2].to_s.lstrip.rstrip.to_i
    max_num = row[3].to_s.lstrip.rstrip.to_i
    prereqs_str = row[4].to_s.lstrip.rstrip
    prereqs = {}
    prereqs_str.split(';').each do  | record|
      kv = record.split(':')
      k = kv[0].to_s.lstrip.rstrip
      v = kv[1].to_s.lstrip.rstrip
      prereqs[k] = v
    end

    item['course_name'] = course_name
    item['num_of_section']  = num_of_section
    item['section'] = 1
    item['min_num'] = min_num
    item['max_num'] = max_num
    item['prereqs'] = prereqs
    item['cur_num'] = 0
    data[course_name] = item
    pp item
    end
    count = count   + 1
  end

  puts "finish course in"
  data
end

def parse_in_student(path)
  student_data = {}
  course_data = {}
  course_data.default = {}

  count = 0
  CSV.foreach path do   |row|
    if count != 0
    student_item = {}
    s_id = row[0].to_s.lstrip.rstrip
    num = row[1].to_s.lstrip.rstrip.to_i
    courses = {}

    (2..5).each do |idx|
      c = parse_choice(row[idx].to_s.lstrip.rstrip)
      if c != nil
        if not course_data.has_key?(c)
          course_data[c] = {}
        end
        course_data[c][s_id] = 1

        courses[c] = 1
      end

    end

    student_item['s_id'] = s_id
    student_item['num'] = num
    student_item['courses'] = courses
    student_item['get'] = 0
    student_data[s_id] = student_item
    pp student_item
    end

    count = count + 1
  end

  puts "finish student in"
  [student_data, course_data]
end

def parse_choice(choice_str)
  kv = choice_str.split(":")
  if (kv.size == 2 and kv[1].to_s.include?('Y')) or kv.size == 1

    kv[0]
  else
    nil
  end
end

main()
