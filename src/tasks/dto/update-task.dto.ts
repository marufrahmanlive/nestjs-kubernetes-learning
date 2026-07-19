import { PartialType } from '@nestjs/mapped-types';
import { CreateTaskDto } from './create-task.dto';

// PartialType makes all fields from CreateTaskDto optional.
// This way PUT /tasks/:id only requires the fields the client wants to change.
export class UpdateTaskDto extends PartialType(CreateTaskDto) {}
