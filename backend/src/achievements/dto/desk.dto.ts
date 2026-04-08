import { IsArray, ArrayMinSize, ArrayMaxSize, IsString } from 'class-validator';

export class SaveDeskDto {
  @IsArray()
  @ArrayMinSize(12)
  @ArrayMaxSize(12)
  @IsString({ each: true })
  desk_layout: string[];
}
